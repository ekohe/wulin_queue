module WulinQueue
  class QueuesController < BaseController
    controller_for_screen SolidQueueQueueScreen

    # The queues view exposes queue_name as its id, so the selected row ids are
    # the queue names.
    def pause
      toolbar_action do
        selected_ids.each { |name| ::SolidQueue::Pause.create_or_find_by!(queue_name: name) }
      end
    end

    def resume
      toolbar_action { ::SolidQueue::Pause.where(queue_name: selected_ids).delete_all }
    end

    # discard_all_in_batches releases the concurrency locks of everything it
    # deletes; deleting the rows directly would leave the semaphores held.
    def clear
      toolbar_action do
        selected_ids.each { |name| ReadyExecution.queued_as(name).discard_all_in_batches }
      end
    end
  end
end
