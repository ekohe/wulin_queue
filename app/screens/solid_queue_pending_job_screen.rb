if defined? WulinMaster
  class SolidQueuePendingJobScreen < WulinMaster::Screen
    title "Pending Jobs"

    path "/wulin_queue/pending_jobs"

    grid SolidQueuePendingJobGrid
  end
end
