# Contributing

Development setup for working on this gem itself. If you're integrating `wulin_queue` into a host app, see `AGENTS.md` and the README instead.

## Commands

```shell
bundle install
bundle exec rake test        # minitest, test/**/*_test.rb
bundle exec standardrb       # lint (must be clean before commit)
bundle exec standardrb --fix # auto-fix lint offenses
```

CI (`.gitlab-ci.yml`) runs `standardrb` then `rake test` on every push.

## Structure

- `lib/wulin_queue.rb` — entry point; `WulinQueue.view_sql` reads a file from `db/views` and substitutes `TABLE_PREFIX_PLACEHOLDER` with `SolidQueue.table_name_prefix`
- `lib/wulin_queue/engine.rb` — `Rails::Engine`, deliberately without `isolate_namespace`; appends `db/migrate` to the host's migration paths
- `config/routes.rb` — draws into `Rails.application.routes`, not the engine's; the engine is never mounted
- `app/models/wulin_queue/` — thin subclasses of Solid Queue's models, plus `Queue`, which reads the `queues` view
- `app/screens/`, `app/grids/` — **top-level** constants (`SolidQueueFailedJobScreen`), because the menu DSL and `params[:screen].classify.safe_constantize` resolve bare names
- `app/controllers/wulin_queue/` — one-liners over `BaseController`, which carries the shared `reject_action_log` and the `ToolbarActions` concern
- `app/assets/javascripts/wulin_queue.js` — the single manifest a host app requires; it pulls in `wulin_queue/action_helpers` and `wulin_queue/actions/*`
- `db/migrate/20260703165109_create_solid_queue_tables.rb` — Solid Queue's schema, with every name built from the table prefix. **Don't run `solid_queue:install` in a host app**; this replaces it
- `db/views/1_queues.sql`, `db/migrate/…_create_wulin_queue_views.rb` — the view name is unprefixed, matching how `wulin_permits` names `user_all_permissions`
- `db/migrate/…_create_wulin_queue_permissions.rb` — all 32 permissions; guarded on `defined?(Permission)`

## Tests

`test/test_helper.rb` boots without a Rails app:

- an in-memory SQLite database, with the **real migration** run against it, so the migration is under test rather than a hand-copied schema
- its own `Zeitwerk` loader over Solid Queue's `app/models` and `app/jobs`, which only a host app's autoloader would otherwise pick up, so the tests run against the real Solid Queue classes
- `ActiveJob::ConcurrencyControls` included and the queue adapter set to `:solid_queue` by hand, both of which the engine normally does in an initializer
- `SolidQueue.use_skip_locked = false`, because `FOR UPDATE SKIP LOCKED` isn't SQLite syntax and every write path goes through a locking read
- a stand-in for `WulinMaster::Grid`/`Screen` that records declarations, so `grid_test.rb` can check them against the models, routes and permission migration

The `Gemfile` pins `solid_queue` to the exact version host apps run, so the suite verifies what actually ships. Bumping that pin is how you check compatibility with a newer Solid Queue.

What deliberately **isn't** tested here: anything that needs `wulin_master`'s own query pipeline, `wulin_permits`, or PostgreSQL. Stubbing wulin_master faithfully enough to test the JSON endpoints would only assert against the stub. Those belong in a host app's suite — drive the nine screens, the toolbar buttons, and a non-admin user who lacks a permission.

`queues_view_test.rb` runs the real view SQL with two PostgreSQL-isms adjusted (`CREATE OR REPLACE VIEW public.` → `CREATE VIEW `), so the query's joins and aggregates are exercised for real. The `paused` column is asserted through raw SQL rather than the model, because SQLite has no boolean type to infer for a view column.

## Conventions

- `wulin_master` is a hard requirement, so don't guard against its absence. It can't go in the gemspec (not on RubyGems), but the gem is useless without it, and a `if defined? WulinMaster` wrapper is worse than nothing: Zeitwerk would then report "expected file to define constant" instead of a plain `uninitialized constant WulinMaster`. The test suite supplies a stand-in.
- `wulin_audit`, `wulin_excel` and `wulin_permits` *are* optional peers. Guard those — `respond_to?(:reject_audit)`, `defined?(WulinExcel)`, `defined?(Permission)`.
- **Never write raw SQL for a delete.** Solid Queue keeps its concurrency semaphores consistent in `before_destroy` callbacks; bypassing the models leaks a semaphore and stalls every blocked job on that key forever. `execution_actions_test.rb` covers this.
- Any column that's a Ruby method rather than a database column needs `sortable: false, filterable: false`. `grid_test.rb` enforces it.
- Default-sort on `id`, never a timestamp — `created_at` is indexed on none of the eleven tables. `grid_test.rb` enforces both halves of that claim.
- A column value that serialises to a JSON *object* is merged into the row by `remotemodel.js` instead of assigned to the column, and the cell renders `undefined`. wulin_master only stringifies a value whose class is exactly `Hash`, so Hash subclasses need an explicit reader override — see `WulinQueue::Process#metadata`. `grid_test.rb` enforces it.
- Every new action needs an `authorized?` block *and* an entry in the permissions migration. `grid_test.rb` enforces both.
- Icons come from Material Icons (https://materializecss.com/icons.html).
- `standardrb` is the formatter/linter; don't hand-format against a different style.
- Prefer the simplest solution: no speculative abstractions, no dead parameters, no code guarding against cases that can't happen.
