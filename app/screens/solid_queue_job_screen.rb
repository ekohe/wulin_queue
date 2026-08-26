class SolidQueueJobScreen < WulinMaster::Screen
  title "Jobs"

  path "/wulin_queue/jobs"

  panel SolidQueueJobStatusPanel
  grid SolidQueueJobGrid
end
