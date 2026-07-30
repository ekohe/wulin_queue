class SolidQueueQueueGrid < WulinMaster::Grid
  title "Queues"

  model WulinQueue::Queue

  path "/wulin_queue/queues"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "ASC"

  column :queue_name, label: "Queue", width: 220
  column :pending_count, label: "Pending", width: 100
  column :scheduled_count, label: "Scheduled", width: 100
  column :blocked_count, label: "Blocked", width: 100
  column :paused, width: 80

  action :pause, title: "Pause", icon: :pause_circle_outline,
    url: "/wulin_queue/queues/pause",
    authorized?: ->(user) { user.has_permission_with_name?("queues#pause") }
  action :resume, title: "Resume", icon: :play_circle_outline,
    url: "/wulin_queue/queues/resume",
    authorized?: ->(user) { user.has_permission_with_name?("queues#resume") }
  action :clear, title: "Clear", icon: :clear_all,
    url: "/wulin_queue/queues/clear",
    authorized?: ->(user) { user.has_permission_with_name?("queues#clear") }
  action :export if defined?(WulinExcel)
end
