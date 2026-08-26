class CreateWulinQueuePermissions < ActiveRecord::Migration[8.1]
  GRID_SCREENS = %w[
    solid_queue_job
    solid_queue_process
    solid_queue_recurring_task
  ].freeze

  PANEL_SCREENS = %w[solid_queue_queue].freeze

  ACTIONS = %w[
    jobs#discard
    jobs#retry
    jobs#retry_all
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
