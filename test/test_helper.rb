require "bundler/setup"
require "minitest/autorun"
require "rails"
require "active_record"
require "active_job"
require "zeitwerk"
require "solid_queue"
require "wulin_queue"

# Solid Queue's models live in its engine's app/models, which only a host app's
# autoloader picks up. Set up our own loader for them and for this gem's models,
# so the tests run against the real classes instead of stand-ins.
GEM_ROOT = Pathname.new(File.expand_path("..", __dir__))

solid_queue_root = Pathname.new(Gem::Specification.find_by_name("solid_queue").gem_dir)

# Stand in for the parts of WulinMaster the screens and grids declare against.
# The real gem is an optional peer, not a dependency; this records declarations so
# the tests can check them against the models, and nothing more. Anything that
# depends on wulin_master's own behaviour belongs in a host app's test suite.
module WulinMaster
  class Grid
    class << self
      attr_reader :declared_columns, :declared_actions, :declared_options

      def inherited(subclass)
        super
        # wulin_master's initialize_columns seeds every grid with a hidden id
        # column; grids sort on it, so the stub has to seed it too.
        subclass.instance_variable_set(:@declared_columns,
          [{name: :id, visible: false, editable: false, sortable: true, always_include: true}])
        subclass.instance_variable_set(:@declared_actions, [])
        subclass.instance_variable_set(:@declared_options, {})
      end

      def title(value = nil) = value ? @title = value : @title
      def model(value = nil) = value ? @model = value : @model
      def path(value = nil) = value ? @path = value : @path

      def column(name, options = {})
        @declared_columns << {name: name}.merge(options)
      end

      def action(name, options = {})
        @declared_actions << {name: name}.merge(options)
      end

      # Positional hashes, not keywords — that is wulin_master's real signature,
      # and it is what makes `default_sorting_state column: "x"` bind to `value`.
      def cell_editable(value = true, options = {}) = @declared_options[:editable] = value

      def multi_select(value = true, options = {}) = @declared_options[:multiSelect] = value

      def default_sorting_state(value = {}, options = {}) = @declared_options[:defaultSortingState] = value

    end
  end

  class Screen
    class << self
      attr_reader :declared_grid, :declared_panel

      def title(value = nil) = value ? @title = value : @title
      def path(value = nil) = value ? @path = value : @path
      def grid(klass) = @declared_grid = klass
      def panel(klass) = @declared_panel = klass
    end
  end

  # Queues has no table to grid, so it is a panel. Only the declarations the
  # panel makes are recorded here; the real Panel's rendering is wulin_master's.
  class Panel
    class << self
      attr_reader :declared_width

      def title(value = nil) = value ? @title = value : @title
      # ComponentStyling's real signature: a value plus an options hash.
      def width(value, options = {}) = @declared_width = value
      def fill_window(value = true, options = {}) = @declared_fill_window = value
    end

    attr_reader :screen, :config

    def initialize(screen = nil, config = {})
      @screen = screen
      @config = config
    end
  end
end

loader = Zeitwerk::Loader.new
loader.push_dir(solid_queue_root.join("app/models"))
loader.push_dir(solid_queue_root.join("app/jobs"))
loader.push_dir(GEM_ROOT.join("app/models"))
loader.push_dir(GEM_ROOT.join("app/grids"))
loader.push_dir(GEM_ROOT.join("app/screens"))
loader.push_dir(GEM_ROOT.join("app/panels"))
loader.setup

# SolidQueue's engine registers this through an initializer, which never runs
# without a full Rails boot. The concurrency tests need it on the job classes.
ActiveJob::Base.include ActiveJob::ConcurrencyControls

# RecurringTask#enqueue takes a different path unless the adapter really is
# Solid Queue, so the default Async adapter would test the wrong branch.
ActiveJob::Base.queue_adapter = :solid_queue
ActiveJob::Base.logger = Logger.new(IO::NULL)

# "FOR UPDATE SKIP LOCKED" is not SQLite syntax. Every write path this gem drives
# goes through a locking read somewhere in Solid Queue.
SolidQueue.use_skip_locked = false
SolidQueue.logger = Logger.new(IO::NULL)

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

# Run this gem's own migration rather than a hand-copied schema — that way the
# migration itself is under test, including the table/index naming.
require GEM_ROOT.join("db/migrate/20260703165109_create_solid_queue_tables.rb").to_s

module WulinQueue
  module TestSchema
    # Loads the Solid Queue tables under `prefix` and yields, then restores the
    # default prefix. Used both for the normal suite and to prove a host app can
    # rename the tables.
    def self.load(prefix: "solid_queue_")
      with_prefix(prefix) do
        ActiveRecord::Migration.suppress_messages { CreateSolidQueueTables.new.migrate(:up) }
        yield if block_given?
      end
    end

    def self.with_prefix(prefix)
      set_prefix(prefix)
      yield
    ensure
      set_prefix("solid_queue_")
    end

    def self.set_prefix(prefix)
      SolidQueue.singleton_class.redefine_method(:table_name_prefix) { prefix }
    end
  end
end

WulinQueue::TestSchema.load

# The gem's models are subclasses, so their table names are computed from the
# prefix that was in force when they were first loaded. Reference them now, while
# the default prefix is active, so later prefix experiments can't leak in.
WulinQueue::Job.table_name

class WulinQueueTestJob < ActiveJob::Base
  def perform(*)
  end
end

class WulinQueueConcurrentTestJob < ActiveJob::Base
  limits_concurrency to: 1, key: ->(*) { "wulin-queue-test" }

  def perform(*)
  end
end

class WulinQueueTestCase < Minitest::Test
  def setup
    tables = ActiveRecord::Base.connection.tables.grep(/\Asolid_queue_/)
    tables.each { |table| ActiveRecord::Base.connection.execute("DELETE FROM #{table}") }
  end

  # Creates a real job row through the model, so after_create dispatches it and
  # leaves behind whichever execution row production would.
  def create_job(class_name: "WulinQueueTestJob", queue_name: "default", concurrency_key: nil,
    scheduled_at: nil, executions: 0)
    SolidQueue::Job.create!(
      queue_name: queue_name,
      class_name: class_name,
      active_job_id: SecureRandom.uuid,
      scheduled_at: scheduled_at,
      concurrency_key: concurrency_key,
      arguments: {"job_class" => class_name, "executions" => executions, "exception_executions" => {"x" => 1}}
    )
  end

  def create_concurrent_job
    create_job(class_name: "WulinQueueConcurrentTestJob", concurrency_key: "wulin-queue-test")
  end

  def create_failed_execution(message: "boom", executions: 0)
    job = create_job(executions: executions)
    job.ready_execution.destroy!

    exception = StandardError.new(message)
    exception.set_backtrace(["app/jobs/a.rb:1", "app/jobs/b.rb:2"])
    job.failed_with(exception)

    WulinQueue::FailedExecution.find_by!(job_id: job.id)
  end
end
