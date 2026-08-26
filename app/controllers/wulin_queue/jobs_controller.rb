module WulinQueue
  class JobsController < BaseController
    controller_for_screen SolidQueueJobScreen

    add_callback :query_initialized, :scope_by_status

    def discard
      toolbar_action do
        jobs = Job.where(id: selected_ids)
        skipped = jobs.select { |j| j.claimed_execution.present? }
        raise "Cannot discard in-progress jobs" if skipped.any?

        jobs.each(&:discard)
      end
    end

    def retry
      toolbar_action do
        executions = FailedExecution.where(job_id: selected_ids)
        raise "Selected jobs are not failed" if executions.empty?

        executions.each(&:retry)
      end
    end

    def retry_all
      toolbar_action do
        ::SolidQueue::FailedExecution.retry_all(
          ::SolidQueue::Job.where(id: FailedExecution.limit(BULK_LIMIT).select(:job_id))
        )
      end
    end

    private

    STATUS_SCOPES = {
      "pending"     => -> { where(id: ReadyExecution.select(:job_id)) },
      "in_progress" => -> { where(id: ClaimedExecution.select(:job_id)) },
      "blocked"     => -> { where(id: BlockedExecution.select(:job_id)) },
      "failed"      => -> { where(id: FailedExecution.select(:job_id)) },
      "scheduled"   => -> { where(id: ScheduledExecution.select(:job_id)) },
      "finished"    => -> { finished }
    }.freeze

    def scope_by_status
      statuses = params[:status].to_s.split(",").filter_map { |s| STATUS_SCOPES[s.strip] }
      return if statuses.empty?

      combined = statuses.reduce(Job.none) { |union, scope| union.or(Job.instance_exec(&scope)) }
      @query = @query.where(id: combined.select(:id))
    end
  end
end
