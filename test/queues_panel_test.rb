require "test_helper"

# Replaces queues_view_test.rb. The `queues` view is gone -- the same rows are
# now assembled in Ruby by SolidQueueQueuePanel -- so every behaviour that test
# pinned down is asserted here against the panel instead, against real job rows
# rather than hand-built execution rows.
class QueuesPanelTest < WulinQueueTestCase
  def rows
    SolidQueueQueuePanel.new.rows
  end

  def row_for(name)
    rows.find { |r| r.name == name }
  end

  def test_it_takes_the_full_width_so_the_card_grid_can_use_it
    # .panel_container is float:left; with no width it shrink-wraps to its
    # content and the card grid wraps earlier than the screen requires.
    assert_equal "100%", SolidQueueQueuePanel.declared_width
  end

  def test_the_screen_declares_the_panel_rather_than_a_grid
    assert_equal SolidQueueQueuePanel, SolidQueueQueueScreen.declared_panel
    assert_nil SolidQueueQueueScreen.declared_grid
  end

  def test_it_lists_no_queues_when_nothing_has_been_enqueued
    assert_empty rows
  end

  # The regression the view existed to avoid: a worker drains the execution
  # tables within milliseconds, so sourcing queue names only from them means a
  # healthy app shows an empty screen -- and you cannot pause what you cannot see.
  def test_it_lists_a_queue_whose_work_has_all_finished
    job = create_job
    job.ready_execution.destroy!
    job.finished!

    assert_equal 0, SolidQueue::ReadyExecution.count, "nothing is waiting any more"

    row = row_for("default")
    assert row, "a drained queue must still be listed, or it can never be paused"
    assert_equal 0, row.pending
  end

  def test_it_lists_a_queue_that_only_a_recurring_task_names
    SolidQueue::RecurringTask.create!(key: "nightly", schedule: "every hour",
      class_name: "WulinQueueTestJob", queue_name: "reports")

    assert row_for("reports"),
      "a queue configured for a recurring task should be listable before it first runs"
  end

  def test_it_lists_a_paused_queue_that_has_no_work_at_all
    SolidQueue::Pause.create!(queue_name: "drained")

    row = row_for("drained")
    assert row, "a paused queue with no work must still be listed, or it can never be resumed"
    assert_equal 0, row.pending
    assert row.paused, "a paused queue must show as paused"
  end

  def test_resuming_clears_the_paused_flag
    create_job
    SolidQueue::Queue.find_by_name("default").pause
    assert row_for("default").paused

    SolidQueue::Queue.find_by_name("default").resume

    refute row_for("default").paused
  end

  def test_it_reports_one_row_per_queue_with_its_own_counts
    2.times { create_job }
    create_job(queue_name: "reports", scheduled_at: Time.now + 3600)

    assert_equal %w[default reports], rows.map(&:name), "sorted by name, one row each"
    assert_equal [2, 0], rows.map(&:pending)
    assert_equal [0, 1], rows.map(&:scheduled)
  end

  def test_it_counts_blocked_jobs_separately
    create_concurrent_job
    create_concurrent_job

    row = row_for("default")
    assert_equal 1, row.pending
    assert_equal 1, row.blocked
  end

  def test_a_queue_named_by_several_tables_is_listed_once
    create_job
    SolidQueue::Pause.create!(queue_name: "default")
    SolidQueue::RecurringTask.create!(key: "n", schedule: "every hour",
      class_name: "WulinQueueTestJob", queue_name: "default")

    assert_equal 1, rows.count { |r| r.name == "default" }
  end

  # The old view built every table name from the prefix. The panel gets that for
  # free by going through the models, so what matters is that they follow it.
  def test_it_follows_a_renamed_solid_queue_table_prefix
    assert_equal "#{SolidQueue.table_name_prefix}pauses", SolidQueue::Pause.table_name
    assert_equal "#{SolidQueue.table_name_prefix}ready_executions", SolidQueue::ReadyExecution.table_name
  end
end
