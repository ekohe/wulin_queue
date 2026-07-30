module WulinQueue
  class ScheduledJobsController < BaseController
    controller_for_screen SolidQueueScheduledJobScreen

    def discard
      toolbar_action { ScheduledExecution.where(id: selected_ids).each(&:discard) }
    end

    # The dispatcher picks up executions whose scheduled_at has passed, so
    # bringing that forward is all "run now" means here. update_all is safe:
    # ScheduledExecution only copies scheduled_at from the job before_create.
    def run_now
      toolbar_action do
        ScheduledExecution.where(id: selected_ids).update_all(scheduled_at: Time.current)
      end
    end
  end
end
