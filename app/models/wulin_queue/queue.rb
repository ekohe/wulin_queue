module WulinQueue
  # SolidQueue::Queue is a plain Ruby object, and a wulin_master grid needs a
  # table, so this reads the `queues` view — see db/views/1_queues.sql. The table
  # name is Rails' default for this class (WulinQueue defines no
  # table_name_prefix), matching how wulin_permits names its views.
  #
  # Inherits SolidQueue::Record, not ActiveRecord::Base, so it follows
  # SolidQueue.connects_to when the host keeps its queue in its own database.
  # reject_audit arrives with it, via the engine's initializer.
  class Queue < ::SolidQueue::Record
    def readonly?
      true
    end
  end
end
