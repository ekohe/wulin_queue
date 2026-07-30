if defined? WulinMaster
  class SolidQueueFailedJobScreen < WulinMaster::Screen
    title "Failed Jobs"

    path "/wulin_queue/failed_jobs"

    grid SolidQueueFailedJobGrid
  end
end
