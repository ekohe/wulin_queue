class SolidQueueBlockedJobGrid < WulinMaster::Grid
  title "Blocked Jobs"

  model WulinQueue::BlockedExecution

  path "/wulin_queue/blocked_jobs"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "ASC"

  column :job_class_name, through: :job, source: :class_name, label: "Job", width: 260
  column :queue_name, width: 120
  column :priority, width: 70
  column :concurrency_key, width: 260
  column :arguments, through: :job, width: 400, sortable: false
  column :active_job_id, through: :job, label: "Job ID", width: 260
  column :created_at, label: "Blocked at", width: 160, type: "Datetime", datetime_format: :with_seconds
  column :expires_at, label: "Block expires at", width: 160, type: "Datetime", datetime_format: :with_seconds

  action :run_now, title: "Run Now", icon: :play_arrow,
    url: "/wulin_queue/blocked_jobs/run_now",
    authorized?: ->(user) { user.has_permission_with_name?("blocked_jobs#run_now") }
  action :discard, title: "Discard", icon: :delete_forever,
    url: "/wulin_queue/blocked_jobs/discard",
    authorized?: ->(user) { user.has_permission_with_name?("blocked_jobs#discard") }
  action :export if defined?(WulinExcel)
end
