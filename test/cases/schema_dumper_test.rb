# frozen_string_literal: true

require "cases/helper_cockroachdb"

require "cases/helper"
require "support/schema_dumping_helper"

module CockroachDB
  class SchemaDumperTest < ActiveRecord::TestCase
    include SchemaDumpingHelper
    self.use_transactional_tests = false

    setup do
      ActiveRecord::SchemaMigration.create_table
    end

    def standard_dump
      @@standard_dump ||= perform_schema_dump
    end

    def perform_schema_dump
      dump_all_table_schema []
    end

    if current_adapter?(:PostgreSQLAdapter)
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
    end
  end
end