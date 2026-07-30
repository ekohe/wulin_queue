module WulinQueue
  class RecurringTask < ::SolidQueue::RecurringTask
    # SolidQueue::RecurringTask#next_time raises when Fugit can't parse the
    # stored schedule, and rows arrive via `create_or_update_all`, which upserts
    # without running validations. One unparseable cron must not take the whole
    # grid down with it.
    def next_time
      super
    rescue
      nil
    end
  end
end
