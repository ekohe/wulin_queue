# WulinQueue

[Solid Queue](https://github.com/rails/solid_queue) screens for [WulinMaster](https://github.com/ekohe/wulin_master) — background jobs as ordinary wulin screens, with the host app's own nav, login, permission model and grid filtering/sorting/export.

Four screens: **Jobs** (with multi-select status filtering), **Queues**, **Processes** and **Recurring Tasks**.

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

The migrations create Solid Queue's tables (so don't also run `solid_queue:install`) and every permission the screens and actions need.

Add the JavaScript to your asset manifest — one line, nothing auto-loads:

```
//= require wulin_queue
```

An engine can't add itself to the menu, so add the submenu to your `ApplicationController.define_menu`:

```ruby
submenu "Background Jobs" do
  item SolidQueueJobScreen, icon: :work
  item SolidQueueQueueScreen, icon: :layers
  item SolidQueueProcessScreen, icon: :memory
  item SolidQueueRecurringTaskScreen, icon: :update
end
```

## How It Works

The unified Jobs screen shows all jobs from `solid_queue_jobs` with a status panel for multi-select filtering. Status is derived from which execution table holds the job (ready → pending, claimed → in_progress, etc.). The controller scopes queries using efficient `WHERE id IN (SELECT job_id FROM ...)` subqueries against the execution tables, so filtering stays index-backed.

The models are thin subclasses of Solid Queue's own (`WulinQueue::FailedExecution < SolidQueue::FailedExecution`). That is safe because `SolidQueue::Execution` is an abstract class and none of the concrete tables has a `type` column, so the subclass inherits its parent's table without Rails adding a single-table-inheritance condition. Retry, discard and dispatch logic comes along for free — see `test/model_test.rb`, which asserts all of this rather than assuming it. `WulinQueue::Job` adds a virtual `status` attribute and error delegation methods (`exception_class`, `error_message`, `backtrace`) for the grid.

**Queues is a panel, not a grid.** A queue is not a record anywhere in Solid Queue — it is a string repeated in the `queue_name` column of six tables — so there is nothing to grid. `SolidQueueQueuePanel` renders it from `SolidQueue::Queue`, whose `.all`, `#paused?`, `#pause`, `#resume`, `#clear` and `#size` already do everything the screen needs.

Earlier versions manufactured rows with a `queues` database view so the grid pipeline had a relation to query. That cost a migration whose version every host app shared, a SQL file, a placeholder token and host-side rake wiring — and because a view name carries no `SolidQueue.table_name_prefix`, two apps sharing a database silently repointed `public.queues` at their own tables on each deploy, so each saw the other's queues. The panel needs none of it.

It lists every queue the app is *known* to use — from the jobs table, the three execution tables, `solid_queue_pauses` and `solid_queue_recurring_tasks` — not just the queues with work waiting right now. A healthy worker drains the execution tables within milliseconds, so sourcing names only from them shows an empty screen on a working app, and a queue you can't see is a queue you can't resume. Five grouped or distinct reads, all index-only.

### Actions

| Action | Screen | What it does |
|---|---|---|
| Retry | Jobs | `FailedExecution#retry` per selected record |
| Retry All | Jobs | `SolidQueue::FailedExecution.retry_all` over every failed job, capped at 3000 |
| Discard | Jobs | `Job#discard` per selected record |
| Show Error | Jobs | renders the stored backtrace in a modal, no request |
| Run Now | Recurring Tasks | enqueues the task now |
| Pause, Resume | Queues | adds or removes the `solid_queue_pauses` row |
| Clear | Queues | `ReadyExecution.queued_as(name).discard_all_in_batches` |

Every write goes **through the ActiveRecord models, never raw SQL**. Discarding a ready job that holds a `concurrency_key` fires `before_destroy :unblock_next_blocked_job`, which signals the semaphore and releases the next blocked job on that key; a raw `DELETE` leaks the semaphore and stalls every blocked job on that key permanently.

**In Progress ships no write actions.** `ClaimedExecution#discard` raises `UndiscardableError`, so a button there could only ever fail.

**Retry and Retry All differ, deliberately.** Per-record `#retry` resets the job's `executions` and `exception_executions` counters, so a `retry_on` budget starts over. `retry_all` can't: resetting counters means rewriting each job's serialized `arguments` one row at a time, which at 3000 rows is a request timeout. It dispatches in one pass and leaves the counters where the last attempt left them.

### Permissions

Screen permissions follow wulin_permits' naming — `SolidQueueJobScreen` gives `solid_queue_job#read` and `#cud`. Custom actions fall through to `<controller>#<action>`, e.g. `jobs#retry`. Every action carries an `authorized?` block, and `db/migrate/…_create_wulin_queue_permissions.rb` creates all permissions; `test/grid_test.rb` fails if an action is added without both.

Hiding a button isn't security: wulin_permits' `create_permissions` before_action independently rejects the request itself, so a user without `failed_jobs#retry` gets a 401 even if they post directly.

### Table prefix

Every table and index name in the migration is built from `SolidQueue.table_name_prefix`. Apps sharing a database with another Solid Queue app can rename them from an initializer:

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

`wulin_master` is a hard requirement — the whole gem is screens, grids and controllers declared against it. It isn't in the gemspec because it isn't published to RubyGems; host apps supply it themselves (`gem "wulin_master", path:` or a git source), which is why this README says to add `wulin_queue` *after* it.

`wulin_audit` and `wulin_excel` are genuinely optional: `reject_audit`/`reject_action_log` are called only when defined, and the Export action only appears when `WulinExcel` is loaded.

Screens and grids are **top-level constants**, not namespaced — the menu DSL and wulin_master's `params[:screen].classify.safe_constantize` both resolve bare constants. Only models and controllers live under `WulinQueue::`. For the same reason the engine does not `isolate_namespace`, and `config/routes.rb` draws into the host application rather than into the engine, so the engine is never mounted.

## Contributing

See `CONTRIBUTING.md`. From [Ekohe](https://ekohe.com).

## License

WulinQueue is released under the MIT license.
