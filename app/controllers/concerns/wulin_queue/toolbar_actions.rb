module WulinQueue
  # Shared plumbing for the grid toolbar actions: the ids of the selected rows,
  # and the JSON envelope WulinQueue.submit expects back.
  #
  # wulin_permits' `create_permissions` before_action already gates every action
  # here on "<controller_name>#<action_name>" — the `authorized?` blocks in the
  # grids only decide whether the button is drawn.
  module ToolbarActions
    extend ActiveSupport::Concern

    # Ceiling on how many records one "... All" click may touch synchronously.
    BULK_LIMIT = 3000

    private

    def selected_ids
      Array(params[:ids])
    end

    def toolbar_action
      yield
      render json: {success: true}
    rescue => e
      Rails.logger.warn "#{controller_path}##{action_name} failed: #{e.class}: #{e.message}"
      render json: {success: false, error_message: e.message}
    end
  end
end
