-- One row per queue that currently has work waiting or is paused.
--
-- The table-prefix token below is substituted with SolidQueue.table_name_prefix
-- (see WulinQueue.view_sql), so this view follows a host app that renames Solid
-- Queue's tables to share a database with another app. The substitution runs in
-- the migration that creates the view and in the host's db:views:create task.
--
-- The queue names come from the three small execution tables plus the pauses
-- table, never from the jobs table: that one holds every finished job ever run,
-- so `SELECT DISTINCT queue_name` over it (what SolidQueue::Queue.all does)
-- full-scans millions of rows to produce a handful of names.
--
-- `queue_name AS id` because wulin_master's grid pipeline selects, counts and
-- looks up rows by `id`.
CREATE OR REPLACE VIEW public.wulin_queue_queues AS
SELECT
  names.queue_name AS id,
  names.queue_name,
  COALESCE(ready.count, 0) AS pending_count,
  COALESCE(scheduled.count, 0) AS scheduled_count,
  COALESCE(blocked.count, 0) AS blocked_count,
  (pauses.queue_name IS NOT NULL) AS paused
FROM (
  SELECT queue_name FROM <solid_queue_prefix>ready_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>scheduled_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>blocked_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>pauses
) names
LEFT JOIN (
  SELECT queue_name, COUNT(*) AS count FROM <solid_queue_prefix>ready_executions GROUP BY queue_name
) ready ON ready.queue_name = names.queue_name
LEFT JOIN (
  SELECT queue_name, COUNT(*) AS count FROM <solid_queue_prefix>scheduled_executions GROUP BY queue_name
) scheduled ON scheduled.queue_name = names.queue_name
LEFT JOIN (
  SELECT queue_name, COUNT(*) AS count FROM <solid_queue_prefix>blocked_executions GROUP BY queue_name
) blocked ON blocked.queue_name = names.queue_name
LEFT JOIN <solid_queue_prefix>pauses pauses ON pauses.queue_name = names.queue_name;
