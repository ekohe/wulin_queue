class SolidQueueQueueScreen < WulinMaster::Screen
  title "Queues"

  path "/wulin_queue/queues"

  # A panel, not a grid: there is no queues table to grid, only a queue_name
  # string repeated across six of them. See SolidQueueQueuePanel.
  panel SolidQueueQueuePanel
end
