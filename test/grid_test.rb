require "test_helper"
require GEM_ROOT.join("db/migrate/20260730120100_create_wulin_queue_permissions.rb").to_s

class GridTest < WulinQueueTestCase
  SCREENS = {
    SolidQueueJobScreen => SolidQueueJobGrid,
    SolidQueueProcessScreen => SolidQueueProcessGrid,
    SolidQueueRecurringTaskScreen => SolidQueueRecurringTaskGrid
  }.freeze

  class PermissionSpy
    attr_reader :asked

    def initialize
      @asked = []
    end

    def has_permission_with_name?(name)
      @asked << name
      true
    end
  end

  def test_every_screen_points_at_its_grid_and_shares_its_path
    SCREENS.each do |screen, grid|
      assert_equal grid, screen.declared_grid
      assert_equal grid.path, screen.path, "#{screen} and #{grid} disagree about the path"
    end
  end

  def test_every_screen_sets_an_explicit_path_under_the_engine_namespace
    SCREENS.each_key do |screen|
      assert_match %r{\A/wulin_queue/[a-z_]+\z}, screen.path, "#{screen} has an odd path"
    end
  end

  def test_every_grid_is_read_only_and_multi_select
    SCREENS.each_value do |grid|
      refute grid.declared_options[:editable], "#{grid} allows cell editing"
      assert grid.declared_options[:multiSelect], "#{grid} can't select multiple rows"
    end
  end

  def test_every_grid_defaults_to_sorting_on_the_primary_key
    SCREENS.each_value do |grid|
      state = grid.declared_options[:defaultSortingState]

      assert state, "#{grid} has no default sort"
      assert_equal "id", state[:column], "#{grid} defaults to sorting on #{state[:column]}"
      assert_includes %w[ASC DESC], state[:direction], "#{grid} has an odd sort direction"
      assert_includes column_identifiers(grid), state[:column]
    end
  end

  def test_no_solid_queue_table_indexes_created_at
    connection = ActiveRecord::Base.connection
    connection.tables.grep(/\Asolid_queue_/).each do |table|
      connection.indexes(table).each do |index|
        refute_includes index.columns, "created_at",
          "#{table} now indexes created_at — revisit the default sort"
      end
    end
  end

  def test_columns_reached_through_an_association_name_a_real_association_and_column
    each_column do |grid, column|
      through = column[:through]
      next unless through

      reflection = grid.model.reflect_on_association(through)
      assert reflection, "#{grid} reads through :#{through}, which #{grid.model} doesn't have"

      source = (column[:source] || column[:name]).to_s
      assert_includes reflection.klass.column_names, source,
        "#{grid} reads #{through}.#{source}, which #{reflection.klass} doesn't have"
    end
  end

  def test_computed_columns_are_neither_sortable_nor_filterable
    each_column do |grid, column|
      next if column[:through]
      next if grid.model.column_names.include?(column[:name].to_s)

      assert grid.model.method_defined?(column[:name]),
        "#{grid} declares #{column[:name]}, which is neither a column nor a method on #{grid.model}"
      assert_equal false, column[:sortable],
        "#{grid}'s #{column[:name]} is computed in Ruby but left sortable"
      assert_equal false, column[:filterable],
        "#{grid}'s #{column[:name]} is computed in Ruby but left filterable"
    end
  end

  def test_no_column_value_serialises_to_a_json_object
    records = {
      WulinQueue::Process => WulinQueue::Process.new(metadata: {"queues" => "*"}),
      WulinQueue::Job => WulinQueue::Job.new(arguments: {"executions" => 0}),
      WulinQueue::RecurringTask => WulinQueue::RecurringTask.new(arguments: [1, 2])
    }

    records.each do |model, record|
      grid = SCREENS.values.find { |g| g.model == model }

      grid.declared_columns.reject { |c| c[:through] }.each do |column|
        value = record.public_send(column[:name])
        next if value.nil? || value.instance_of?(Hash)

        refute_kind_of Hash, value,
          "#{grid}'s #{column[:name]} is a #{value.class}, which wulin_master won't stringify — " \
          "the cell will render as undefined"
      end
    end
  end

  def test_the_process_grid_shows_every_process_kind
    assert_equal WulinQueue::Process, SolidQueueProcessGrid.model
    assert_includes column_identifiers(SolidQueueProcessGrid), "kind"
  end

  def test_every_action_is_gated_on_a_permission
    each_action do |grid, action|
      assert_kind_of Proc, action[:authorized?], "#{grid}'s #{action[:name]} has no authorized? block"

      spy = PermissionSpy.new
      action[:authorized?].call(spy)

      assert_equal 1, spy.asked.size, "#{grid}'s #{action[:name]} checks #{spy.asked.inspect}"
    end
  end

  def test_every_action_permission_is_created_by_the_migration
    created = migration_permissions

    each_action do |grid, action|
      spy = PermissionSpy.new
      action[:authorized?].call(spy)

      assert_includes created, spy.asked.first,
        "#{grid}'s #{action[:name]} needs #{spy.asked.first}, which no migration creates"
    end
  end

  def test_every_screen_permission_is_created_by_the_migration
    SCREENS.each_key do |screen|
      name = screen.name.sub(/Screen\z/, "").underscore

      assert_includes CreateWulinQueuePermissions::GRID_SCREENS, name,
        "no migration creates #{name}#read for #{screen}"
    end
  end

  def test_the_panel_screen_permission_is_created_by_the_migration
    name = SolidQueueQueueScreen.name.sub(/Screen\z/, "").underscore

    assert_includes CreateWulinQueuePermissions::PANEL_SCREENS, name
    assert_includes migration_permissions, "#{name}#read"
    refute_includes migration_permissions, "#{name}#cud",
      "Queues has no create/update/destroy route, so a #cud permission is never checked"
  end

  def test_show_error_has_every_field_it_reads_guaranteed_on_the_row
    columns = SolidQueueJobGrid.declared_columns.index_by { |c| c[:name] }

    %i[exception_class error_message backtrace].each do |name|
      column = columns[name]
      assert column, "the job grid must carry #{name} for show_error"
      assert column[:always_include], "show_error reads #{name}, so it must be always_include"
    end

    assert_equal false, columns[:backtrace][:visible], "the backtrace is for the modal, not the grid"
  end

  def migration_permissions
    CreateWulinQueuePermissions::ACTIONS +
      CreateWulinQueuePermissions::GRID_SCREENS.flat_map { |s| ["#{s}#read", "#{s}#cud"] } +
      CreateWulinQueuePermissions::PANEL_SCREENS.map { |s| "#{s}#read" }
  end

  def test_every_action_posts_to_its_own_grids_url
    each_action do |grid, action|
      url = action[:url]
      next unless url

      assert_equal "#{grid.path}/#{action[:name]}", url,
        "#{grid}'s #{action[:name]} posts to #{url}"
    end
  end

  private

  def each_column
    SCREENS.each_value { |grid| grid.declared_columns.each { |column| yield grid, column } }
  end

  def each_action
    SCREENS.each_value { |grid| grid.declared_actions.each { |action| yield grid, action } }
  end

  def column_identifiers(grid)
    grid.declared_columns.map do |column|
      if column[:through]
        "#{column[:through]}_#{column[:source] || column[:name]}"
      elsif column[:source]
        "#{column[:name]}_#{column[:source]}"
      else
        column[:name].to_s
      end
    end
  end
end
