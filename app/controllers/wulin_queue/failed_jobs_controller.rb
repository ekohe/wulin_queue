if defined? WulinMaster
  module WulinQueue
    class FailedJobsController < BaseController
      controller_for_screen SolidQueueFailedJobScreen

      # Per-record, so FailedExecution#retry resets the job's `executions` and
      # `exception_executions` counters and any `retry_on` budget starts over.
      def retry
        toolbar_action { FailedExecution.where(id: selected_ids).each(&:retry) }
      end

      # Every failed job, not just the selection. Bulk on purpose: the per-record
      # path resets counters by rewriting each job's serialized arguments, which
      # is four queries a row and cannot be batched — at BULK_LIMIT rows that is
      # a request timeout, so this dispatches in one pass and leaves the counters
      # where the last attempt left them.
      def retry_all
        toolbar_action { ::SolidQueue::FailedExecution.retry_all(all_failed_jobs) }
      end

      def discard
        toolbar_action { FailedExecution.where(id: selected_ids).each(&:discard) }
      end

      def discard_all
        toolbar_action { ::SolidQueue::FailedExecution.discard_all_from_jobs(all_failed_jobs) }
      end

      private

      def all_failed_jobs
        ::SolidQueue::Job.where(id: FailedExecution.limit(BULK_LIMIT).select(:job_id))
      end
    end
  end
end
