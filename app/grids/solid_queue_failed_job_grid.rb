if defined? WulinMaster
  class SolidQueueFailedJobGrid < WulinMaster::Grid
    title "Failed Jobs"

    model WulinQueue::FailedExecution

    path "/wulin_queue/failed_jobs"

    cell_editable false
    multi_select
    default_sorting_state column: "id", direction: "DESC"

    # solid_queue_failed_executions has no queue_name or priority of its own.
    column :job_class_name, through: :job, source: :class_name, label: "Job", width: 260
    column :queue_name, through: :job, width: 120
    column :arguments, through: :job, width: 400, sortable: false
    column :active_job_id, through: :job, label: "Job ID", width: 260
    column :created_at, label: "Failed at", width: 160, type: "Datetime", datetime_format: :with_seconds

    # exception_class / message / backtrace read the serialized `error` JSON in
    # Ruby, so the database can neither sort nor filter on them.
    #
    # All three are always_include because show_error builds its modal from the
    # row it already has, without a request. Without that, hiding the Error or
    # Message column drops it from the `columns` param and the modal comes up
    # blank — wulin_master only sends the columns currently on screen.
    column :exception_class, label: "Error", width: 220, always_include: true,
      sortable: false, filterable: false
    column :message, width: 400, always_include: true, sortable: false, filterable: false
    column :backtrace, visible: false, always_include: true, excel_export: false,
      sortable: false, filterable: false

    action :retry, title: "Retry", icon: :replay,
      url: "/wulin_queue/failed_jobs/retry",
      authorized?: ->(user) { user.has_permission_with_name?("failed_jobs#retry") }
    action :retry_all, title: "Retry All", icon: :refresh, global: true,
      url: "/wulin_queue/failed_jobs/retry_all",
      authorized?: ->(user) { user.has_permission_with_name?("failed_jobs#retry_all") }
    action :discard, title: "Discard", icon: :delete_forever,
      url: "/wulin_queue/failed_jobs/discard",
      authorized?: ->(user) { user.has_permission_with_name?("failed_jobs#discard") }
    action :discard_all, title: "Discard All", icon: :delete_sweep, global: true,
      url: "/wulin_queue/failed_jobs/discard_all",
      authorized?: ->(user) { user.has_permission_with_name?("failed_jobs#discard_all") }
    action :show_error, title: "Show Error", icon: :bug_report,
      authorized?: ->(user) { user.has_permission_with_name?("solid_queue_failed_job#read") }
    action :export if defined?(WulinExcel)
  end
end
