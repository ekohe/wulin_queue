if defined? WulinMaster
  class SolidQueueRecurringTaskGrid < WulinMaster::Grid
    title "Recurring Tasks"

    model WulinQueue::RecurringTask

    path "/wulin_queue/recurring_tasks"

    cell_editable false
    multi_select
    default_sorting_state column: "id", direction: "ASC"

    column :key, width: 260
    column :class_name, label: "Job", width: 260
    column :command, width: 400
    column :schedule, width: 200
    column :arguments, width: 300, sortable: false
    column :queue_name, width: 120
    column :priority, width: 70
    column :static, width: 70
    column :description, width: 300

    # Both are computed in Ruby — next_time parses the cron with Fugit,
    # last_enqueued_time aggregates solid_queue_recurring_executions.
    column :next_time, label: "Next run", width: 160, type: "Datetime",
      datetime_format: :with_seconds, sortable: false, filterable: false
    column :last_enqueued_time, label: "Last enqueued", width: 160, type: "Datetime",
      datetime_format: :with_seconds, sortable: false, filterable: false

    action :run_now, title: "Run Now", icon: :play_arrow,
      url: "/wulin_queue/recurring_tasks/run_now",
      authorized?: ->(user) { user.has_permission_with_name?("recurring_tasks#run_now") }
    action :export if defined?(WulinExcel)
  end
end
