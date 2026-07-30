if defined? WulinMaster
  class SolidQueueInProgressJobScreen < WulinMaster::Screen
    title "In Progress Jobs"

    path "/wulin_queue/in_progress_jobs"

    grid SolidQueueInProgressJobGrid
  end
end
