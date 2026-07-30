require "solid_queue"
require "wulin_queue/version"
require "wulin_queue/engine" if defined? Rails

module WulinQueue
  # Placeholder in db/views/*.sql for whatever SolidQueue.table_name_prefix is,
  # so the views follow a host app that renames Solid Queue's tables to share a
  # database with another app.
  TABLE_PREFIX_PLACEHOLDER = "<solid_queue_prefix>"

  def self.views_path
    Engine.config.root.join("db", "views")
  end

  def self.view_sql(file_name)
    File.read(views_path.join(file_name))
      .gsub(TABLE_PREFIX_PLACEHOLDER, SolidQueue.table_name_prefix)
  end
end
