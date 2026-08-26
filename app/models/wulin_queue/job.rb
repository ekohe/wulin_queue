module WulinQueue
  class Job < ::SolidQueue::Job
    def status
      if finished_at?
        "finished"
      elsif failed_execution
        "failed"
      elsif claimed_execution
        "in_progress"
      elsif blocked_execution
        "blocked"
      elsif scheduled_execution
        "scheduled"
      elsif ready_execution
        "pending"
      end
    end

    def exception_class
      failed_execution&.exception_class
    end

    def error_message
      failed_execution&.message
    end

    def backtrace
      failed_execution&.backtrace
    end
  end
end
