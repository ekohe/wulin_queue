if defined? WulinMaster
  class SolidQueueScheduledJobScreen < WulinMaster::Screen
    title "Scheduled Jobs"

    path "/wulin_queue/scheduled_jobs"

    grid SolidQueueScheduledJobGrid
  end
end
