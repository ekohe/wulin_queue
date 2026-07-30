-- One row per queue the app is known to use, with what is waiting on it and
-- whether it is paused.
--
-- The table-prefix token below is substituted with SolidQueue.table_name_prefix
-- (see WulinQueue.view_sql), so this view follows a host app that renames Solid
-- Queue's tables to share a database with another app. The substitution runs in
-- the migration that creates the view and in the host's db:views:create task.
--
-- Listing every *known* queue, not just the ones with work waiting right now, is
-- the point: with a healthy worker the execution tables are empty almost all the
-- time, and a queue you can't see is a queue you can't pause — which is exactly
-- what you want to do to an idle queue before a deploy.
--
-- Reading the jobs table for that is cheap despite its size: `SELECT DISTINCT
-- queue_name` is an index-only scan over index_<prefix>jobs_for_filtering, the
-- DISTINCT collapses it to one row per queue before the UNION sees it, and the
-- table is bounded by SolidQueue.clear_finished_jobs_after.
--
-- `queue_name AS id` because wulin_master's grid pipeline selects, counts and
-- looks up rows by `id`.
CREATE OR REPLACE VIEW public.queues AS
SELECT
  names.queue_name AS id,
  names.queue_name,
  COALESCE(ready.count, 0) AS pending_count,
  COALESCE(scheduled.count, 0) AS scheduled_count,
  COALESCE(blocked.count, 0) AS blocked_count,
  (pauses.queue_name IS NOT NULL) AS paused
FROM (
  SELECT DISTINCT queue_name FROM <solid_queue_prefix>jobs
  UNION
  SELECT queue_name FROM <solid_queue_prefix>ready_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>scheduled_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>blocked_executions
  UNION
  SELECT queue_name FROM <solid_queue_prefix>pauses
  UNION
  SELECT queue_name FROM <solid_queue_prefix>recurring_tasks WHERE queue_name IS NOT NULL
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
