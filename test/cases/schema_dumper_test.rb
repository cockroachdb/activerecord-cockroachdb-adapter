# frozen_string_literal: true

require "cases/helper_cockroachdb"

require "cases/helper"
require "support/schema_dumping_helper"

module CockroachDB
  class SchemaDumperTest < ActiveRecord::TestCase
    include SchemaDumpingHelper
    self.use_transactional_tests = false

    setup do
      @schema_migration = ActiveRecord::Base.connection.schema_migration
      @schema_migration.create_table
    end

    def standard_dump
      @@standard_dump ||= perform_schema_dump
    end

    def perform_schema_dump
      dump_all_table_schema []
    end

    # OVERRIDE: we removed the 'deferrable' part in `assert_match`
    def test_schema_dumps_unique_constraints
      output = dump_table_schema("test_unique_constraints")
      constraint_definitions = output.split(/\n/).grep(/t\.unique_constraint/)

      assert_equal 3, constraint_definitions.size
      assert_match 't.unique_constraint ["position_1"], name: "test_unique_constraints_position_1"', output
      assert_match 't.unique_constraint ["position_2"], name: "test_unique_constraints_position_2"', output
      assert_match 't.unique_constraint ["position_3"], name: "test_unique_constraints_position_3"', output
    end

    def test_schema_dump_with_timestamptz_datetime_format
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_cockroachdb_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration::Current) do
          def up
            create_table("timestamps") do |t|
              t.datetime :this_should_remain_datetime
              t.timestamptz :this_is_an_alias_of_datetime
              t.column :without_time_zone, :timestamp
              t.column :with_time_zone, :timestamptz
            end
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = perform_schema_dump
        assert output.include?('t.datetime "this_should_remain_datetime"')
        assert output.include?('t.datetime "this_is_an_alias_of_datetime"')
        assert output.include?('t.timestamp "without_time_zone"')
        assert output.include?('t.datetime "with_time_zone"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column_with_type_as_string
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_cockroachdb_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps")

            add_column :timestamps, :this_should_change_to_timestamp, "datetime"
            add_column :timestamps, :this_should_stay_as_timestamp, "timestamp"
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = perform_schema_dump
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.
        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_timestamps_schema_dump_before_rails_7_with_timestamptz_setting
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_cockroachdb_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps") do |t|
              t.datetime :this_should_change_to_timestamp
              t.timestamp :this_should_stay_as_timestamp
              t.column :this_should_also_stay_as_timestamp, :timestamp
            end
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = perform_schema_dump
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.

        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
        assert output.include?('t.timestamp "this_should_also_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column_before_rails_7_with_timestamptz_setting
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_cockroachdb_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps")

            add_column :timestamps, :this_should_change_to_timestamp, :datetime
            add_column :timestamps, :this_should_stay_as_timestamp, :timestamp
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = perform_schema_dump
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.

        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_when_changing_datetime_type_for_an_existing_app
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_table("timestamps") do |t|
            t.datetime :default_format
            t.column :without_time_zone, :timestamp
            t.column :with_time_zone, :timestamptz
          end
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = perform_schema_dump
      assert output.include?('t.datetime "default_format"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.timestamptz "with_time_zone"')

      datetime_type_was = ActiveRecord::ConnectionAdapters::CockroachDBAdapter.datetime_type
      ActiveRecord::ConnectionAdapters::CockroachDBAdapter.datetime_type = :timestamptz

      output = perform_schema_dump
      assert output.include?('t.timestamp "default_format"')
      assert output.include?('t.timestamp "without_time_zone"')
      assert output.include?('t.datetime "with_time_zone"')
    ensure
      ActiveRecord::ConnectionAdapters::CockroachDBAdapter.datetime_type = datetime_type_was
      migration.migrate(:down)
      $stdout = original
    end

    if ActiveRecord::Base.connection.supports_check_constraints?
      def test_schema_dumps_check_constraints
        constraint_definition = dump_table_schema("products").split(/\n/).grep(/t.check_constraint.*products_price_check/).first.strip
        if current_adapter?(:Mysql2Adapter)
          assert_equal 't.check_constraint "`price` > `discounted_price`", name: "products_price_check"', constraint_definition
        else
          assert_equal 't.check_constraint "(price > discounted_price)", name: "products_price_check"', constraint_definition
        end
      end
    end
  end
end
