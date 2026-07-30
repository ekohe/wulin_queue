class SolidQueueBlockedJobScreen < WulinMaster::Screen
  title "Blocked Jobs"

  path "/wulin_queue/blocked_jobs"

  grid SolidQueueBlockedJobGrid
end
