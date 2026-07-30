class CreateWulinQueueViews < ActiveRecord::Migration[8.1]
  def up
    execute WulinQueue.view_sql("1_queues.sql")
  end

  def down
    execute "DROP VIEW IF EXISTS public.queues"
  end
end
