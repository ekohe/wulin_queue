if defined? WulinMaster
  module WulinQueue
    class FinishedJobsController < BaseController
      controller_for_screen SolidQueueFinishedJobScreen

      add_callback :query_initialized, :only_finished

      def only_finished
        @query = @query.finished
      end

      # A finished job has no execution row left to discard, so this deletes the
      # job itself.
      def discard
        toolbar_action { Job.finished.where(id: selected_ids).destroy_all }
      end
    end
  end
end
