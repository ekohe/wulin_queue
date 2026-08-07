class CreateWulinQueuePermissions < ActiveRecord::Migration[8.1]
  GRID_SCREENS = %w[
    solid_queue_pending_job
    solid_queue_in_progress_job
    solid_queue_blocked_job
    solid_queue_failed_job
    solid_queue_scheduled_job
    solid_queue_finished_job
    solid_queue_process
    solid_queue_recurring_task
  ].freeze

  # Queues is a panel rather than a grid, and its only route is index -- a read
  # action. None of wulin_permits' CUD_ACTIONS (new/edit/create/update/destroy)
  # has a route here, so a solid_queue_queue#cud permission would never be
  # checked. Its three write actions are gated as queues#pause / #resume /
  # #clear below, which is how wulin_permits names a non-read, non-CUD action.
  PANEL_SCREENS = %w[solid_queue_queue].freeze

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
    GRID_SCREENS.flat_map { |screen| ["#{screen}#read", "#{screen}#cud"] } +
      PANEL_SCREENS.map { |screen| "#{screen}#read" } +
      ACTIONS
  end
end
