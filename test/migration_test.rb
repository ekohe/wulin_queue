require "test_helper"

# The migration builds every table and index name from SolidQueue.table_name_prefix
# so a host app can rename the tables to share a database with another Solid Queue
# app. Two things have to hold: the default prefix must reproduce exactly the names
# solid_queue's own installer writes (existing databases must not drift), and any
# longer prefix must still fit PostgreSQL's identifier limit.
class MigrationTest < WulinQueueTestCase
  TABLES = %w[
    blocked_executions claimed_executions failed_executions jobs pauses processes
    ready_executions recurring_executions recurring_tasks scheduled_executions semaphores
  ].freeze

  # Verbatim from solid_queue's own installer, so drift shows up as a failure.
  DEFAULT_INDEX_NAMES = %w[
    index_solid_queue_blocked_executions_for_maintenance
    index_solid_queue_blocked_executions_for_release
    index_solid_queue_blocked_executions_on_job_id
    index_solid_queue_claimed_executions_on_job_id
    index_solid_queue_claimed_executions_on_process_id_and_job_id
    index_solid_queue_dispatch_all
    index_solid_queue_failed_executions_on_job_id
    index_solid_queue_jobs_for_alerting
    index_solid_queue_jobs_for_filtering
    index_solid_queue_jobs_on_active_job_id
    index_solid_queue_jobs_on_class_name
    index_solid_queue_jobs_on_finished_at
    index_solid_queue_pauses_on_queue_name
    index_solid_queue_poll_all
    index_solid_queue_poll_by_queue
    index_solid_queue_processes_on_last_heartbeat_at
    index_solid_queue_processes_on_name_and_supervisor_id
    index_solid_queue_processes_on_supervisor_id
    index_solid_queue_ready_executions_on_job_id
    index_solid_queue_recurring_executions_on_job_id
    index_solid_queue_recurring_executions_on_task_key_and_run_at
    index_solid_queue_recurring_tasks_on_key
    index_solid_queue_recurring_tasks_on_static
    index_solid_queue_scheduled_executions_on_job_id
    index_solid_queue_semaphores_on_expires_at
    index_solid_queue_semaphores_on_key
    index_solid_queue_semaphores_on_key_and_value
  ].freeze

  def test_default_prefix_creates_solid_queues_own_table_names
    assert_equal TABLES.map { |t| "solid_queue_#{t}" }.sort, existing_tables("solid_queue_")
  end

  def test_default_prefix_creates_solid_queues_own_index_names
    assert_equal DEFAULT_INDEX_NAMES, index_names_for("solid_queue_")
  end

  def test_a_custom_prefix_renames_every_table
    with_schema("wq_alt_") do
      assert_equal TABLES.map { |t| "wq_alt_#{t}" }.sort, existing_tables("wq_alt_")
    end
  end

  def test_a_custom_prefix_renames_every_index
    with_schema("wq_alt_") do
      names = index_names_for("wq_alt_")

      assert_equal DEFAULT_INDEX_NAMES.size, names.size
      assert names.all? { |name| name.include?("wq_alt_") }, "some index kept the old prefix"
    end
  end

  # The default names already run to 61 of PostgreSQL's 63 identifier bytes, so a
  # realistic per-app prefix overflows two of them. Rails raises on an over-long
  # index name rather than truncating, so the migration shortens them itself.
  def test_a_long_prefix_keeps_index_names_within_the_identifier_limit
    limit = ActiveRecord::Base.connection.index_name_length

    with_schema("waldo_solid_queue_") do
      names = index_names_for("waldo_solid_queue_")

      assert_equal DEFAULT_INDEX_NAMES.size, names.size
      assert_equal names.size, names.uniq.size, "shortening collided two index names"
      assert names.all? { |name| name.length <= limit },
        "over-long index names: #{names.select { |n| n.length > limit }.inspect}"
    end
  end

  def test_only_the_overflowing_names_get_a_digest_suffix
    with_schema("waldo_solid_queue_") do
      digested = index_names_for("waldo_solid_queue_").grep(/_[0-9a-f]{8}\z/)

      assert_equal 2, digested.size, "expected exactly the two names that overflow: #{digested.inspect}"
    end
  end

  private

  def with_schema(prefix)
    WulinQueue::TestSchema.with_prefix(prefix) do
      ActiveRecord::Migration.suppress_messages do
        CreateSolidQueueTables.new.migrate(:up)
        yield
      ensure
        CreateSolidQueueTables.new.migrate(:down)
      end
    end
  end

  def existing_tables(prefix)
    ActiveRecord::Base.connection.tables.grep(/\A#{prefix}/).sort
  end

  def index_names_for(prefix)
    connection = ActiveRecord::Base.connection
    existing_tables(prefix).flat_map { |table| connection.indexes(table).map(&:name) }.sort
  end
end
