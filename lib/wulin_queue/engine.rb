require "rails"

module WulinQueue
  class Engine < Rails::Engine
    engine_name :wulin_queue

    # No isolate_namespace: screens and grids have to be top-level constants so
    # the host app's menu DSL and wulin_master's `params[:screen].classify` lookup
    # can resolve them. Only models and controllers live under WulinQueue::.

    # Solid Queue's tables are high-churn plumbing — executions, process
    # heartbeats, recurring-task upserts. Keeping them out of wulin_audit's
    # audit_logs is this gem's business rather than every host app's, and
    # reject_audit on the abstract base class covers every model. A no-op when
    # wulin_audit isn't loaded, since it's an optional peer.
    initializer "wulin_queue.reject_audit" do
      ActiveSupport.on_load(:solid_queue_record) do
        reject_audit if respond_to?(:reject_audit)
      end
    end

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
  end
end
