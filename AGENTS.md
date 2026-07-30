# AGENTS.md

`wulin_queue` is a Rails engine, never run standalone — it's always loaded into a host app alongside [`wulin_master`](https://github.com/ekohe/wulin_master). It puts Solid Queue's tables behind nine ordinary wulin screens. This file is for agents working in a host app that consumes this gem. If you're developing the gem itself, see `CONTRIBUTING.md`.

## Wiring it into a host app

Four steps, all in the README's Installation section: the Gemfile, `db:migrate`, `//= require wulin_queue` in the asset manifest, and the `submenu "Background Jobs"` block in `ApplicationController.define_menu`. An engine can't add itself to the menu, and nothing auto-loads the JS.

- **Do not run `solid_queue:install`.** `db/migrate/20260703165109_create_solid_queue_tables.rb` in this gem *is* Solid Queue's schema. A host that already ran the installer keeps its own migration and must not also get this one — check `schema_migrations` before adding the gem to an app that already had Solid Queue.
- `solid_queue` arrives as a runtime dependency of this gem. A host app that also drives it directly (`bin/jobs`, `config/queue.yml`, `config.active_job.queue_adapter`) should still declare it in its own Gemfile — that's a direct dependency, not a transitive one.
- If the host rebuilds views from `db/views/*.sql` for test databases (Rails' Ruby schema format doesn't dump views, so anything loaded from `schema.rb` loses them), that task needs this gem's view directory **and** the placeholder substitution — see the README. Without the substitution the view SQL is created with a literal `<solid_queue_prefix>` and fails.
- Permissions are not auto-created on deploy in general, but this gem's migration creates all 32. After deploying, someone still has to *assign* them; until then only admins see the screens.

## Gotchas

- **Never write raw SQL to delete a job or execution.** Discarding a *ready* job that has a `concurrency_key` fires `Job#unblock_next_blocked_job`, which signals the semaphore and releases the next blocked job on that key. `ReadyExecution.discard_jobs` likewise calls `Job.release_all_concurrency_locks` first. Bypassing the models leaks the semaphore and stalls every blocked job on that key permanently. Every action in this gem goes through the ActiveRecord models for exactly this reason.
- Screens and grids are **top-level** constants (`SolidQueueFailedJobScreen`), not under `WulinQueue::`. The engine has no `isolate_namespace`, because the menu DSL and wulin_master's `params[:screen].classify.safe_constantize` resolve bare names. Only models and controllers are namespaced. `config/routes.rb` draws into `Rails.application.routes`, so **the engine is never mounted** — don't add `mount WulinQueue::Engine`.
- The route and controller action is `run_now`, not `dispatch`: `ActionController::Metal` already defines an instance method called `dispatch`, and overriding it breaks request handling.
- `claimed` and `failed` executions have **no** `queue_name` or `priority` column of their own — those come `through: :job`. `ready`/`scheduled`/`blocked` have them natively, and the native column is used so filters hit `index_solid_queue_poll_by_queue` instead of the join.
- Any grid column that's a Ruby method rather than a database column (`exception_class`, `message`, `next_time`, `last_enqueued_time`) must carry `sortable: false, filterable: false`, or wulin_master asks the database to `ORDER BY` something that isn't there.
- **Never default-sort on a timestamp.** `created_at` is indexed on none of the eleven Solid Queue tables, so ordering by it is an unindexed sort of the whole table — and the finished-jobs table is the big one. Every grid defaults to `column: "id"`: it's the primary key, it's indexed, and because these tables are insert-only it gives the same order. Users can still click any column header.
- **A column whose value serialises to a JSON object renders as `undefined`.** `remotemodel.js` does `$.extend(true, obj, item)` for objects — that's how it merges association payloads — so a plain object is folded into the row instead of assigned to the column. wulin_master's `Column#format` stringifies a `Hash`, but only when `value.class == Hash` exactly, so Hash *subclasses* slip through. `store :metadata, coder: JSON` returns a `HashWithIndifferentAccess`, which is why `WulinQueue::Process#metadata` overrides the reader to return `to_json`. Adding a column backed by any hash-like value needs the same treatment.
- The **In Progress** screen intentionally has no write actions: `ClaimedExecution#discard` raises `UndiscardableError`.
- **Retry** and **Retry All** are not the same operation. Per-record `#retry` resets the job's execution counters; the bulk path can't without rewriting each job's serialized `arguments` one row at a time, which is a timeout at 3000 rows. Documented in the README; don't "fix" one to match the other without solving that.
- The **Processes** screen shows every process kind — Supervisor, Dispatcher, Scheduler, Worker. Don't filter it down to workers: the dispatcher and scheduler are usually the two that explain a stalled queue.
- Changing `SolidQueue.table_name_prefix` after tables exist renames nothing — it only affects a fresh migration. And a prefix longer than about 14 characters pushes two index names past PostgreSQL's 63-byte limit; the migration shortens those two with a digest suffix rather than letting Rails raise.

## Verifying integration behavior

Claims about grid rendering, toolbar actions or permissions can't be settled from this repo alone — half the behaviour is `wulin_master`'s query pipeline and `wulin_permits`' before_action, neither of which is a dependency here. This gem's own suite (`bundle exec rake test`) covers the models, the migration's naming, the view SQL, the write paths, and the grid declarations against the models and permission migration. It deliberately does not fake wulin_master.

Before trusting an assumption about WulinMaster or host-app behaviour, check it against a local checkout:

- `wulin_master` — the grid/screen/action engine these screens declare against; `lib/wulin_master/components/grid/column.rb` decides what `through:`/`source:` actually mean, and `lib/wulin_master/actions.rb` is the query pipeline
- `wulin_permits` — `lib/wulin_permits/extensions/screen.rb` derives screen permission names, `extensions/screen_controller.rb` gates custom actions on `<controller>#<action>`
- a host app that vendors this gem — grep its `app/assets/javascripts/application.js` for how the JS is required, and its `ApplicationController` for the menu block

End-to-end, in a host app: run `bin/rails s` and `bin/jobs`, walk the nine screens from the nav, make a job raise, then retry it from Failed and watch it move Pending → In Progress → Finished. Pause a queue from Queues and confirm new jobs stop being claimed. Test the buttons as a **non-admin** user: admin bypasses every permission check and hides a missing `authorized?` block.
