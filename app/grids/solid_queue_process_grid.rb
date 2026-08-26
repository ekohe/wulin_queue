class SolidQueueProcessGrid < WulinMaster::Grid
  title "Processes"

  # Every process kind — Supervisor, Dispatcher, Scheduler and Worker. Don't
  # filter this down to workers: the dispatcher and scheduler are usually the two
  # that explain a stalled queue.
  model WulinQueue::Process

  path "/wulin_queue/processes"

  cell_editable false
  multi_select
  default_sorting_state column: "id", direction: "ASC"

  column :kind, width: 110
  column :name, width: 260
  column :hostname, width: 180
  column :pid, width: 80
  column :supervisor_name, through: :supervisor, source: :name, label: "Supervisor", width: 260
  column :last_heartbeat_at, width: 160, type: "Datetime", datetime_format: :with_seconds
  column :created_at, label: "Started at", width: 160, type: "Datetime", datetime_format: :with_seconds
  column :metadata, width: 300, editable: false, formatter: "JsonFormatter"

  action :export if defined?(WulinExcel)
end
