class CreateWulinQueuePermissions < ActiveRecord::Migration[8.1]
  SCREENS = %w[
    solid_queue_pending_job
    solid_queue_in_progress_job
    solid_queue_blocked_job
    solid_queue_failed_job
    solid_queue_scheduled_job
    solid_queue_finished_job
    solid_queue_queue
    solid_queue_process
    solid_queue_recurring_task
  ].freeze

  # wulin_permits derives these from [controller_name, action_name] for any
  # action that isn't a plain read or CUD — see WulinQueue's AGENTS.md.
  ACTIONS = %w[
    pending_jobs#discard
    blocked_jobs#discard
    blocked_jobs#run_now
    failed_jobs#retry
    failed_jobs#retry_all
    failed_jobs#discard
    failed_jobs#discard_all
    scheduled_jobs#discard
    scheduled_jobs#run_now
    finished_jobs#discard
    queues#pause
    queues#resume
    queues#clear
    recurring_tasks#run_now
  ].freeze

  def up
    return unless defined?(Permission)

    permission_names.each { |name| Permission.find_or_create_by!(name: name) }
  end

  def down
    return unless defined?(Permission)

    permission_names.each { |name| Permission.find_by(name: name)&.destroy }
  end

  private

  def permission_names
    SCREENS.flat_map { |screen| ["#{screen}#read", "#{screen}#cud"] } + ACTIONS
  end
end
