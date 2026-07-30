if defined? WulinMaster
  class SolidQueueQueueScreen < WulinMaster::Screen
    title "Queues"

    path "/wulin_queue/queues"

    grid SolidQueueQueueGrid
  end
end
