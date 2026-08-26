class SolidQueueJobGrid < WulinMaster::Grid
  title "Jobs"

  model WulinQueue::Job

  path "/wulin_queue/jobs"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "DESC"

  column :status, width: 100, sortable: false, filterable: false
  column :class_name, label: "Job", width: 260
  column :queue_name, width: 120
  column :priority, width: 70
  column :arguments, width: 400, sortable: false, editable: false, formatter: "JsonFormatter"
  column :active_job_id, label: "Job ID", width: 260
  column :concurrency_key, width: 260, visible: false
  column :created_at, label: "Enqueued at", width: 160, type: "Datetime", datetime_format: :with_seconds
  column :finished_at, width: 160, type: "Datetime", datetime_format: :with_seconds, visible: false

  column :exception_class, label: "Error", width: 220, always_include: true,
    sortable: false, filterable: false, visible: false
  column :error_message, label: "Message", width: 400, always_include: true,
    sortable: false, filterable: false, visible: false
  column :backtrace, visible: false, always_include: true, excel_export: false,
    sortable: false, filterable: false

  action :discard, title: "Discard", icon: :delete_forever,
    url: "/wulin_queue/jobs/discard",
    authorized?: ->(user) { user.has_permission_with_name?("jobs#discard") }
  action :retry, title: "Retry", icon: :replay,
    url: "/wulin_queue/jobs/retry",
    authorized?: ->(user) { user.has_permission_with_name?("jobs#retry") }
  action :retry_all, title: "Retry All", icon: :refresh, global: true,
    url: "/wulin_queue/jobs/retry_all",
    authorized?: ->(user) { user.has_permission_with_name?("jobs#retry_all") }
  action :show_error, title: "Show Error", icon: :bug_report,
    authorized?: ->(user) { user.has_permission_with_name?("solid_queue_job#read") }
  action :export if defined?(WulinExcel)
end
