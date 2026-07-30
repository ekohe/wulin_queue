require "test_helper"

# The queues screen is the one place this gem writes its own SQL, so the view's
# counts and paused flag are checked against real rows rather than eyeballed.
class QueuesViewTest < WulinQueueTestCase
  def test_the_view_follows_the_solid_queue_table_prefix
    sql = WulinQueue::TestSchema.with_prefix("wq_alt_") do
      WulinQueue.view_sql("1_queues.sql")
    end

    assert_includes sql, "FROM wq_alt_ready_executions"
    assert_includes sql, "LEFT JOIN wq_alt_pauses"
    refute_includes sql, WulinQueue::TABLE_PREFIX_PLACEHOLDER
    refute_includes sql, "solid_queue_", "the default prefix leaked into a renamed view"
  end

  # The regression: a worker drains the execution tables within milliseconds, so
  # sourcing queue names only from them means a healthy app shows an empty Queues
  # screen — and you cannot pause a queue you cannot see.
  def test_it_lists_a_queue_whose_work_has_all_finished
    job = create_job
    job.ready_execution.destroy!
    job.finished!

    assert_equal 0, WulinQueue::ReadyExecution.count, "nothing is waiting any more"

    row = WulinQueue::Queue.find_by(queue_name: "default")

    assert row, "a drained queue must still be listed, or it can never be paused"
    assert_equal 0, row.pending_count
  end

  def test_it_lists_a_queue_that_only_a_recurring_task_names
    WulinQueue::RecurringTask.create!(key: "nightly", schedule: "every hour",
      class_name: "WulinQueueTestJob", queue_name: "reports")

    assert WulinQueue::Queue.find_by(queue_name: "reports"),
      "a queue configured for a recurring task should be listable before it first runs"
  end

  def test_it_reads_queue_names_from_the_jobs_table_with_a_pushed_down_distinct
    # Cheap despite the table's size: DISTINCT lets PostgreSQL answer from
    # index_<prefix>jobs_for_filtering and collapse to one row per queue before
    # the UNION sees it. Without the DISTINCT every finished job would be fed
    # into the UNION's dedupe.
    assert_match(/SELECT DISTINCT queue_name FROM solid_queue_jobs/,
      WulinQueue.view_sql("1_queues.sql"))
  end

  def test_it_reports_one_row_per_queue_with_work
    create_job(queue_name: "default")
    create_job(queue_name: "default")
    create_job(queue_name: "reports", scheduled_at: 1.hour.from_now)

    rows = WulinQueue::Queue.order(:queue_name).to_a

    assert_equal %w[default reports], rows.map(&:queue_name)
    assert_equal [2, 0], rows.map(&:pending_count)
    assert_equal [0, 1], rows.map(&:scheduled_count)
  end

  def test_it_counts_blocked_jobs
    create_concurrent_job
    create_concurrent_job

    row = WulinQueue::Queue.find_by!(queue_name: "default")

    assert_equal 1, row.pending_count
    assert_equal 1, row.blocked_count
  end

  def test_it_uses_the_queue_name_as_the_row_id
    # wulin_master's grid pipeline selects, counts and looks up rows by `id`, and
    # the pause/resume/clear actions post those ids back as queue names.
    create_job(queue_name: "reports")

    assert_equal "reports", WulinQueue::Queue.first.id
  end

  def test_it_lists_a_paused_queue_that_has_no_work_at_all
    SolidQueue::Pause.create!(queue_name: "drained")

    row = WulinQueue::Queue.find_by!(queue_name: "drained")

    assert_equal 0, row.pending_count
    assert paused?("drained"), "a paused queue must show as paused"
  end

  def test_resuming_clears_the_paused_flag
    create_job(queue_name: "default")
    SolidQueue::Pause.create!(queue_name: "default")
    assert paused?("default")

    SolidQueue::Pause.where(queue_name: ["default"]).delete_all

    refute paused?("default")
  end

  private

  # Asserted through raw SQL: the `paused` expression is a real boolean on
  # PostgreSQL, but SQLite has no boolean type to infer for a view column, so
  # going through the model here would test SQLite's type guessing, not the view.
  def paused?(queue_name)
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.sanitize_sql(["SELECT paused FROM queues WHERE queue_name = ?", queue_name])
    ).to_s.in?(%w[1 t true])
  end
end
