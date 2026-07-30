if defined? WulinMaster
  module WulinQueue
    # Common wiring for the nine screen controllers; each one only declares its
    # screen and its write actions.
    class BaseController < WulinMaster::ScreenController
      include WulinQueue::ToolbarActions

      # reject_action_log is wulin_audit's, and wulin_audit is not a dependency.
      # These screens are pure plumbing views — logging every poll of them into
      # action_logs is noise.
      reject_action_log if respond_to?(:reject_action_log)
    end
  end
end
