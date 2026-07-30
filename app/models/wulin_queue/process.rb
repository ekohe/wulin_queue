module WulinQueue
  class Process < ::SolidQueue::Process
    # `store :metadata, coder: JSON` hands back an ActiveSupport::HashWithIndifferentAccess.
    # wulin_master's Column#format only stringifies a value when `value.class == Hash`
    # — the exact class — so a Hash subclass reaches the payload as a JSON object,
    # and remotemodel.js merges objects into the row instead of assigning them to
    # the column, leaving the cell undefined. Hand it a string instead.
    #
    # Safe to override here: Solid Queue's own processes are SolidQueue::Process,
    # so nothing in the runtime reads this.
    def metadata
      super&.to_json
    end
  end
end
