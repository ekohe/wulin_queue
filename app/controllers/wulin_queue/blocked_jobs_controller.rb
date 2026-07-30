if defined? WulinMaster
  module WulinQueue
    class BlockedJobsController < BaseController
      controller_for_screen SolidQueueBlockedJobScreen

      def discard
        toolbar_action { BlockedExecution.where(id: selected_ids).each(&:discard) }
      end

      # Promote to ready without waiting for the semaphore — the whole point of
      # the button is to override the concurrency limit that is holding the job.
      def run_now
        toolbar_action do
          BlockedExecution.where(id: selected_ids).includes(:job).each do |execution|
            execution.transaction do
              execution.job.dispatch_bypassing_concurrency_limits
              execution.destroy!
            end
          end
        end
      end
    end
  end
end
