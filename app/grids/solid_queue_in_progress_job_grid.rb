class SolidQueueInProgressJobGrid < WulinMaster::Grid
  title "In Progress Jobs"

  model WulinQueue::ClaimedExecution

  path "/wulin_queue/in_progress_jobs"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "ASC"

  # solid_queue_claimed_executions has no queue_name or priority of its own.
  column :job_class_name, through: :job, source: :class_name, label: "Job", width: 260
  column :queue_name, through: :job, width: 120
  column :priority, through: :job, width: 70
  column :arguments, through: :job, width: 400, sortable: false
  column :active_job_id, through: :job, label: "Job ID", width: 260
  column :process_name, through: :process, source: :name, label: "Process", width: 200
  column :created_at, label: "Claimed at", width: 160, type: "Datetime", datetime_format: :with_seconds

  # No write actions: ClaimedExecution#discard raises UndiscardableError, so a
  # Discard button here could only ever fail.
  action :export if defined?(WulinExcel)
end
