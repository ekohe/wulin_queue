module WulinQueue
  class RecurringTasksController < BaseController
    controller_for_screen SolidQueueRecurringTaskScreen

    # Rows reach solid_queue_recurring_tasks through upsert_all, which skips
    # validations, so a task can be stored with a schedule Fugit can't parse or
    # a class that no longer exists. Enqueueing those raises; report them
    # instead, after running the ones that are fine.
    def run_now
      toolbar_action do
        runnable, invalid = RecurringTask.where(id: selected_ids).partition(&:valid?)
        runnable.each { |task| task.enqueue(at: Time.current) }
        raise "Skipped #{invalid.map(&:key).to_sentence}: invalid schedule or job class" if invalid.any?
      end
    end
  end
end
