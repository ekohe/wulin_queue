class SolidQueueFinishedJobGrid < WulinMaster::Grid
  title "Finished Jobs"

  # The base query is scoped to `.finished` in the controller.
  model WulinQueue::Job

  path "/wulin_queue/finished_jobs"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "DESC"

  column :class_name, label: "Job", width: 260
  column :queue_name, width: 120
  column :priority, width: 70
  column :arguments, width: 400, sortable: false
  column :active_job_id, label: "Job ID", width: 260
  column :concurrency_key, width: 260
  column :created_at, label: "Enqueued at", width: 160, type: "Datetime", datetime_format: :with_seconds
  column :finished_at, width: 160, type: "Datetime", datetime_format: :with_seconds

  action :discard, title: "Discard", icon: :delete_forever,
    url: "/wulin_queue/finished_jobs/discard",
    authorized?: ->(user) { user.has_permission_with_name?("finished_jobs#discard") }
  action :export if defined?(WulinExcel)
end
