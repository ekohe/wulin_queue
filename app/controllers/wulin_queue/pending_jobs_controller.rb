module WulinQueue
  class PendingJobsController < BaseController
    controller_for_screen SolidQueuePendingJobScreen

    # ReadyExecution#discard destroys the job through the model, which fires
    # Job#unblock_next_blocked_job — that signals the semaphore and releases
    # the next blocked job on the same concurrency key. A raw DELETE would
    # leak the semaphore and stall that key forever.
    def discard
      toolbar_action { ReadyExecution.where(id: selected_ids).each(&:discard) }
    end
  end
end
