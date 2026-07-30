require "test_helper"

# The toolbar actions, driven at exactly the level the controllers drive them.
# Going through the models is the whole point: Solid Queue keeps its concurrency
# semaphores consistent in before_destroy callbacks, so a raw DELETE would leak a
# semaphore and stall every blocked job on that key forever.
class ExecutionActionsTest < WulinQueueTestCase
  # --- Failed screen -------------------------------------------------------

  def test_retry_resets_the_execution_counters_and_makes_the_job_ready
    failed = create_failed_execution(executions: 3)
    job = failed.job

    failed.retry

    refute WulinQueue::FailedExecution.exists?(failed.id)
    assert job.reload.ready_execution.present?
    assert_equal 0, job.arguments["executions"]
    assert_equal({}, job.arguments["exception_executions"])
  end

  def test_retry_all_dispatches_every_failed_job
    2.times { create_failed_execution }

    SolidQueue::FailedExecution.retry_all(all_failed_jobs)

    assert_equal 0, WulinQueue::FailedExecution.count
    assert_equal 2, WulinQueue::ReadyExecution.count
  end

  def test_discard_removes_the_failed_execution_and_its_job
    failed = create_failed_execution

    failed.discard

    refute WulinQueue::FailedExecution.exists?(failed.id)
    assert_equal 0, WulinQueue::Job.count
  end

  def test_discard_all_removes_every_failed_job
    2.times { create_failed_execution }

    SolidQueue::FailedExecution.discard_all_from_jobs(all_failed_jobs)

    assert_equal 0, WulinQueue::FailedExecution.count
    assert_equal 0, WulinQueue::Job.count
  end

  # --- Pending screen ------------------------------------------------------

  def test_discarding_a_pending_job_removes_it
    ready = create_job.ready_execution

    ready.discard

    refute WulinQueue::ReadyExecution.exists?(ready.id)
    assert_equal 0, WulinQueue::Job.count
  end

  # The regression a raw DELETE would introduce.
  def test_discarding_a_pending_job_releases_its_semaphore_and_unblocks_the_next
    running = create_concurrent_job
    blocked = create_concurrent_job

    assert running.ready_execution.present?, "first job should hold the semaphore and be ready"
    assert blocked.blocked_execution.present?, "second job should be blocked on the same key"
    assert_equal 0, SolidQueue::Semaphore.find_by!(key: "wulin-queue-test").value

    WulinQueue::ReadyExecution.find(running.ready_execution.id).discard

    assert_nil blocked.reload.blocked_execution
    assert blocked.ready_execution.present?, "the blocked job should have been promoted to ready"
  end

  # --- Blocked screen ------------------------------------------------------

  def test_run_now_promotes_a_blocked_job_past_its_concurrency_limit
    create_concurrent_job
    job = create_concurrent_job
    blocked = WulinQueue::BlockedExecution.find(job.blocked_execution.id)

    blocked.transaction do
      blocked.job.dispatch_bypassing_concurrency_limits
      blocked.destroy!
    end

    refute WulinQueue::BlockedExecution.exists?(blocked.id)
    assert job.reload.ready_execution.present?
  end

  def test_discarding_a_blocked_job_removes_it
    create_concurrent_job
    blocked = WulinQueue::BlockedExecution.find(create_concurrent_job.blocked_execution.id)

    blocked.discard

    refute WulinQueue::BlockedExecution.exists?(blocked.id)
  end

  # --- Scheduled screen ----------------------------------------------------

  def test_run_now_brings_a_scheduled_execution_forward_so_the_dispatcher_sees_it
    job = create_job(scheduled_at: 1.hour.from_now)
    scheduled = job.scheduled_execution

    assert scheduled.present?, "a future job should be scheduled, not ready"
    assert_equal 0, SolidQueue::ScheduledExecution.due.count

    WulinQueue::ScheduledExecution.where(id: scheduled.id).update_all(scheduled_at: Time.current)

    assert_equal 1, SolidQueue::ScheduledExecution.due.count
  end

  def test_discarding_a_scheduled_job_removes_it
    scheduled = create_job(scheduled_at: 1.hour.from_now).scheduled_execution

    WulinQueue::ScheduledExecution.find(scheduled.id).discard

    refute WulinQueue::ScheduledExecution.exists?(scheduled.id)
    assert_equal 0, WulinQueue::Job.count
  end

  # --- Finished screen -----------------------------------------------------

  def test_discarding_a_finished_job_deletes_the_job_row
    job = create_job
    job.ready_execution.destroy!
    job.finished!

    assert_equal 1, WulinQueue::Job.finished.count

    WulinQueue::Job.finished.destroy_all

    assert_equal 0, WulinQueue::Job.count
  end

  # --- Queues screen -------------------------------------------------------

  def test_pause_and_resume_toggle_the_pauses_row
    SolidQueue::Pause.create_or_find_by!(queue_name: "default")
    assert SolidQueue::Pause.exists?(queue_name: "default")

    # Pausing twice must not raise — the button is idempotent.
    SolidQueue::Pause.create_or_find_by!(queue_name: "default")
    assert_equal 1, SolidQueue::Pause.count

    SolidQueue::Pause.where(queue_name: ["default"]).delete_all
    refute SolidQueue::Pause.exists?(queue_name: "default")
  end

  def test_clear_discards_every_pending_job_on_the_queue_and_releases_semaphores
    create_job(queue_name: "default")
    create_concurrent_job
    create_job(queue_name: "other")

    WulinQueue::ReadyExecution.queued_as("default").discard_all_in_batches

    assert_equal 0, WulinQueue::ReadyExecution.queued_as("default").count
    assert_equal 1, WulinQueue::ReadyExecution.queued_as("other").count
    # discard_all_in_batches calls Job.release_all_concurrency_locks first.
    assert_equal 1, SolidQueue::Semaphore.find_by!(key: "wulin-queue-test").value
  end

  # --- Recurring tasks screen ---------------------------------------------

  def test_run_now_enqueues_a_valid_recurring_task
    task = WulinQueue::RecurringTask.create!(key: "good", schedule: "every hour",
      class_name: "WulinQueueTestJob")

    assert task.valid?
    assert_difference_in_jobs(1) { task.enqueue(at: Time.current) }
  end

  def test_run_now_skips_a_task_whose_job_class_is_gone
    WulinQueue::RecurringTask.insert_all([{key: "gone", schedule: "every hour",
                                           class_name: "NoSuchJob", static: true,
                                           created_at: Time.current, updated_at: Time.current}])
    task = WulinQueue::RecurringTask.find_by!(key: "gone")

    refute task.valid?, "the controller relies on valid? to skip unenqueueable tasks"
  end

  private

  # Mirrors FailedJobsController#all_failed_jobs.
  def all_failed_jobs
    SolidQueue::Job.where(id: WulinQueue::FailedExecution.limit(3000).select(:job_id))
  end

  def assert_difference_in_jobs(count)
    before = WulinQueue::Job.count
    yield
    assert_equal before + count, WulinQueue::Job.count
  end
end
