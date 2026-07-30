require "test_helper"

# The whole design rests on one claim: you can subclass Solid Queue's models
# without Rails treating the subclass as single-table inheritance. If that were
# wrong every grid would silently return zero rows, so it is asserted here rather
# than assumed.
class ModelTest < WulinQueueTestCase
  SUBCLASSES = {
    WulinQueue::Job => "solid_queue_jobs",
    WulinQueue::ReadyExecution => "solid_queue_ready_executions",
    WulinQueue::ClaimedExecution => "solid_queue_claimed_executions",
    WulinQueue::BlockedExecution => "solid_queue_blocked_executions",
    WulinQueue::FailedExecution => "solid_queue_failed_executions",
    WulinQueue::ScheduledExecution => "solid_queue_scheduled_executions",
    WulinQueue::Process => "solid_queue_processes",
    WulinQueue::RecurringTask => "solid_queue_recurring_tasks"
  }.freeze

  def test_subclasses_inherit_their_parent_table
    SUBCLASSES.each do |model, table|
      assert_equal table, model.table_name, "#{model} reads the wrong table"
    end
  end

  def test_subclasses_do_not_add_an_sti_type_condition
    SUBCLASSES.each_key do |model|
      refute model.finder_needs_type_condition?, "#{model} would filter on a type column"
      refute_includes model.all.to_sql, "type", "#{model}'s default scope mentions a type column"
    end
  end

  def test_no_solid_queue_table_has_a_type_column
    # This is *why* the subclassing is safe — if solid_queue ever adds a `type`
    # column, every grid starts returning nothing and this test says so first.
    SUBCLASSES.each_key do |model|
      refute_includes model.column_names, "type", "#{model.table_name} gained a type column"
    end
  end

  def test_execution_type_still_reports_the_parent_name
    # SolidQueue derives this from model_name.element, and the retry/discard
    # instrumentation and discard_all_in_batches depend on it.
    assert_equal :ready, WulinQueue::ReadyExecution.type
    assert_equal :failed, WulinQueue::FailedExecution.type
    assert_equal :blocked, WulinQueue::BlockedExecution.type
    assert_equal :scheduled, WulinQueue::ScheduledExecution.type
    assert_equal :claimed, WulinQueue::ClaimedExecution.type
  end

  def test_inherited_associations_resolve_into_the_solid_queue_namespace
    # The reflections were defined on SolidQueue's classes, so they must keep
    # pointing at SolidQueue's classes and not look for WulinQueue::Job.
    assert_equal SolidQueue::Job, WulinQueue::FailedExecution.reflect_on_association(:job).klass
    assert_equal SolidQueue::Job, WulinQueue::ReadyExecution.reflect_on_association(:job).klass
    assert_equal SolidQueue::Process, WulinQueue::ClaimedExecution.reflect_on_association(:process).klass
    assert_equal SolidQueue::Process, WulinQueue::Process.reflect_on_association(:supervisor).klass
  end

  def test_belongs_to_job_is_queryable_through_the_subclass
    job = create_job
    job.ready_execution.destroy!
    job.failed_with(StandardError.new("boom"))

    execution = WulinQueue::FailedExecution.includes(:job).first

    assert_equal job.id, execution.job.id
    assert_equal "WulinQueueTestJob", execution.job.class_name
  end

  def test_failed_execution_exposes_the_serialized_error
    execution = create_failed_execution(message: "kaboom")

    assert_equal "StandardError", execution.exception_class
    assert_equal "kaboom", execution.message
    assert_equal ["app/jobs/a.rb:1", "app/jobs/b.rb:2"], execution.backtrace
  end

  def test_recurring_task_next_time_parses_a_valid_schedule
    task = WulinQueue::RecurringTask.create!(key: "good", schedule: "every hour",
      class_name: "WulinQueueTestJob")

    assert_kind_of Time, task.next_time
  end

  def test_recurring_task_next_time_swallows_an_unparseable_schedule
    # upsert_all skips validations, so a schedule Fugit can't parse really does
    # reach the table. One bad row must not take the grid down.
    WulinQueue::RecurringTask.insert_all([{key: "bad", schedule: "not a cron",
                                           class_name: "WulinQueueTestJob", static: true,
                                           created_at: Time.current, updated_at: Time.current}])

    task = WulinQueue::RecurringTask.find_by!(key: "bad")

    assert_raises(StandardError) { SolidQueue::RecurringTask.find_by!(key: "bad").next_time }
    assert_nil task.next_time
  end

  def test_queue_reads_the_view_and_is_readonly
    assert_equal "queues", WulinQueue::Queue.table_name
    assert_predicate WulinQueue::Queue.new, :readonly?
  end
end
