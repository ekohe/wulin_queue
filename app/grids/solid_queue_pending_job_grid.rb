if defined? WulinMaster
  class SolidQueuePendingJobGrid < WulinMaster::Grid
    title "Pending Jobs"

    model WulinQueue::ReadyExecution

    path "/wulin_queue/pending_jobs"

    cell_editable false
    multi_select
    default_sorting_state column: "id", direction: "ASC"

    column :job_class_name, through: :job, source: :class_name, label: "Job", width: 260
    column :queue_name, width: 120
    column :priority, width: 70
    column :arguments, through: :job, width: 400, sortable: false
    column :active_job_id, through: :job, label: "Job ID", width: 260
    column :created_at, label: "Enqueued at", width: 160, type: "Datetime", datetime_format: :with_seconds

    action :discard, title: "Discard", icon: :delete_forever,
      url: "/wulin_queue/pending_jobs/discard",
      authorized?: ->(user) { user.has_permission_with_name?("pending_jobs#discard") }
    action :export if defined?(WulinExcel)
  end
end
