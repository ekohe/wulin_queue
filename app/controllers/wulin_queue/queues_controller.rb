module WulinQueue
  # The Queues screen is a panel rather than a grid, so these act on the single
  # queue_name its buttons post instead of a set of selected row ids, and they
  # redirect back to the screen instead of answering the grid's JSON envelope.
  #
  # Every operation is SolidQueue::Queue's own. Nothing about a queue is stored,
  # so find_by_name only wraps the string -- there is no record to miss.
  class QueuesController < BaseController
    controller_for_screen SolidQueueQueueScreen

    def pause
      queue_action(&:pause)
    end

    def resume
      queue_action(&:resume)
    end

    # #clear goes through ReadyExecution.discard_all_in_batches, which releases
    # the concurrency locks of everything it deletes. Deleting the rows directly
    # would leave the semaphores held and stall every blocked job on that key.
    def clear
      queue_action(&:clear)
    end

    private

    def queue_action
      name = params[:queue_name].presence
      return redirect_to screen_path, alert: "No queue given." if name.nil?

      yield ::SolidQueue::Queue.find_by_name(name)
      redirect_to screen_path, notice: "#{action_name.capitalize} done for #{name}."
    rescue => e
      Rails.logger.warn "#{controller_path}##{action_name} failed: #{e.class}: #{e.message}"
      redirect_to screen_path, alert: "#{action_name.capitalize} failed: #{e.message}"
    end

    def screen_path
      "#{SolidQueueQueueScreen.path}?screen=#{SolidQueueQueueScreen}"
    end
  end
end
