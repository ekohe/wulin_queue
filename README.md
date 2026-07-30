# WulinQueue

[Solid Queue](https://github.com/rails/solid_queue) screens for [WulinMaster](https://github.com/ekohe/wulin_master) — background jobs as ordinary wulin screens, with the host app's own nav, login, permission model and grid filtering/sorting/export.

Nine screens: **Pending**, **In Progress**, **Blocked**, **Failed**, **Scheduled** and **Finished** jobs, plus **Queues**, **Processes** and **Recurring Tasks**.

Replaces [mission_control-jobs](https://github.com/rails/mission_control-jobs), which ships its own layout, stylesheet, Turbo/Stimulus controllers and HTTP basic auth, and renders outside the host's nav and permission system.

## Installation

Add to your Gemfile, after `wulin_master`:

```ruby
gem "wulin_queue"
```

`solid_queue` comes along as a dependency. Then:

```shell
bundle install
bin/rails db:migrate
```

The migrations create Solid Queue's tables (so don't also run `solid_queue:install`), the `queues` view, and every permission the screens and actions need.

Add the JavaScript to your asset manifest — one line, nothing auto-loads:

```
//= require wulin_queue
```

An engine can't add itself to the menu, so add the submenu to your `ApplicationController.define_menu`:

```ruby
submenu "Background Jobs" do
  item SolidQueuePendingJobScreen, icon: :hourglass_empty
  item SolidQueueInProgressJobScreen, icon: :play_circle_outline
  item SolidQueueBlockedJobScreen, icon: :block
  item SolidQueueFailedJobScreen, icon: :error_outline
  item SolidQueueScheduledJobScreen, icon: :schedule
  item SolidQueueFinishedJobScreen, icon: :done_all
  item SolidQueueQueueScreen, icon: :layers
  item SolidQueueProcessScreen, icon: :memory
  item SolidQueueRecurringTaskScreen, icon: :update
end
```

If your app rebuilds views from `db/views/*.sql` (Rails' Ruby schema format doesn't dump views, so test databases loaded from `schema.rb` lose them), add this gem's view directory to that task and substitute the table-prefix placeholder:

```ruby
WulinQueue::Engine.config.root.join("db", "views", "*.sql")
# ...
view_content.gsub!(WulinQueue::TABLE_PREFIX_PLACEHOLDER, SolidQueue.table_name_prefix)
```

## How It Works

Each grid is backed by its **own execution table** — `solid_queue_ready_executions` for Pending, `solid_queue_failed_executions` for Failed, and so on — rather than by a computed status column over `solid_queue_jobs`. Every one of those tables has a unique index on `job_id`, and the job's own attributes arrive through `includes(:job)`, so there is no status derivation and no `EXISTS` scanning.

The models are thin subclasses of Solid Queue's own (`WulinQueue::FailedExecution < SolidQueue::FailedExecution`). That is safe because `SolidQueue::Execution` is an abstract class and none of the concrete tables has a `type` column, so the subclass inherits its parent's table without Rails adding a single-table-inheritance condition. Retry, discard and dispatch logic comes along for free — see `test/model_test.rb`, which asserts all of this rather than assuming it.

**`WulinQueue::Queue` is different.** `SolidQueue::Queue` is a plain Ruby object, and a grid needs a table, so it reads the `queues` view.

That view lists every queue the app is *known* to use — from the jobs table, the three execution tables, `solid_queue_pauses` and `solid_queue_recurring_tasks` — not just the queues with work waiting right now. That distinction matters: a healthy worker drains the execution tables within milliseconds, so sourcing names only from them shows an empty screen on a working app, and a queue you can't see is a queue you can't pause. Reading the jobs table for the names is cheap despite its size, because `SELECT DISTINCT queue_name` is an index-only scan over `index_solid_queue_jobs_for_filtering`, the `DISTINCT` collapses it to one row per queue before the `UNION` sees it, and the table is bounded by `SolidQueue.clear_finished_jobs_after`.

### Actions

| Action | Screens | What it does |
|---|---|---|
| Retry | Failed | `FailedExecution#retry` per record, so execution counters reset |
| Retry All | Failed | `SolidQueue::FailedExecution.retry_all` over every failed job, capped at 3000 |
| Discard | Failed, Pending, Scheduled, Blocked, Finished | `Execution#discard`, or deletes the job on Finished |
| Discard All | Failed | `discard_all_from_jobs` over every failed job, capped at 3000 |
| Run Now | Blocked, Scheduled, Recurring Tasks | dispatches past the concurrency limit / brings `scheduled_at` forward / enqueues now |
| Pause, Resume | Queues | adds or removes the `solid_queue_pauses` row |
| Clear | Queues | `ReadyExecution.queued_as(name).discard_all_in_batches` |
| Show Error | Failed | renders the stored backtrace in a modal, no request |

Every write goes **through the ActiveRecord models, never raw SQL**. Discarding a ready job that holds a `concurrency_key` fires `before_destroy :unblock_next_blocked_job`, which signals the semaphore and releases the next blocked job on that key; a raw `DELETE` leaks the semaphore and stalls every blocked job on that key permanently.

**In Progress ships no write actions.** `ClaimedExecution#discard` raises `UndiscardableError`, so a button there could only ever fail.

**Retry and Retry All differ, deliberately.** Per-record `#retry` resets the job's `executions` and `exception_executions` counters, so a `retry_on` budget starts over. `retry_all` can't: resetting counters means rewriting each job's serialized `arguments` one row at a time, which at 3000 rows is a request timeout. It dispatches in one pass and leaves the counters where the last attempt left them.

### Permissions

Screen permissions follow wulin_permits' naming — `SolidQueueFailedJobScreen` gives `solid_queue_failed_job#read` and `#cud`. Custom actions fall through to `<controller>#<action>`, e.g. `failed_jobs#retry`. Every action carries an `authorized?` block, and `db/migrate/…_create_wulin_queue_permissions.rb` creates all 32 permissions; `test/grid_test.rb` fails if an action is added without both.

Hiding a button isn't security: wulin_permits' `create_permissions` before_action independently rejects the request itself, so a user without `failed_jobs#retry` gets a 401 even if they post directly.

### Table prefix

Every table and index name in the migration, and every table the view reads, is built from `SolidQueue.table_name_prefix`. Apps sharing a database with another Solid Queue app can rename them from an initializer:

```ruby
# config/initializers/solid_queue.rb
module SolidQueue
  def self.table_name_prefix
    "myapp_solid_queue_"
  end
end
```

It has to be an initializer: Rails' `isolate_namespace` defines the default during boot, and this file runs after that but before any Solid Queue model computes its `table_name`.

Solid Queue's default index names already run to 61 of PostgreSQL's 63 identifier bytes, and Rails raises on an over-long index name rather than truncating. Two of them overflow with any longer prefix, so the migration shortens those two and appends a digest of the full name.

## WulinMaster Integration

`WulinMaster` is an optional peer, not a dependency: every screen, grid and controller is guarded with `if defined? WulinMaster`, and the models load without it. `reject_audit` and `reject_action_log` come from `wulin_audit`, also not a dependency, and are called only when present.

Screens and grids are **top-level constants**, not namespaced — the menu DSL and wulin_master's `params[:screen].classify.safe_constantize` both resolve bare constants. Only models and controllers live under `WulinQueue::`. For the same reason the engine does not `isolate_namespace`, and `config/routes.rb` draws into the host application rather than into the engine, so the engine is never mounted.

## Contributing

See `CONTRIBUTING.md`. From [Ekohe](https://ekohe.com).

## License

WulinQueue is released under the MIT license.
