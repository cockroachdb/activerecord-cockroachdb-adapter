# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/developer"
require "models/topic"

module CockroachDB
  class PostgresqlTimestampMigrationTest < ActiveRecord::PostgreSQLTestCase
    self.use_transactional_tests = false

    class PostgresqlTimestampWithZone < ActiveRecord::Base; end

    def test_adds_column_as_timestamp
      original, $stdout = $stdout, StringIO.new

      ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime

      assert_equal({ "data_type" => "timestamp without time zone" },
                  PostgresqlTimestampWithZone.connection.execute("select data_type from information_schema.columns where column_name = 'times'").to_a.first)
    ensure
      ActiveRecord::Migration.new.remove_column :postgresql_timestamp_with_zones, :times, if_exists: true
      $stdout = original
    end

    def test_adds_column_as_timestamptz_if_datetime_type_changed
      original, $stdout = $stdout, StringIO.new

      with_cockroachdb_datetime_type(:timestamptz) do
        ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime

        assert_equal({ "data_type" => "timestamp with time zone" },
                    PostgresqlTimestampWithZone.connection.execute("select data_type from information_schema.columns where column_name = 'times'").to_a.first)
      end
    ensure
      ActiveRecord::Migration.new.remove_column :postgresql_timestamp_with_zones, :times, if_exists: true
      $stdout = original
    end

    def test_adds_column_as_custom_type
      original, $stdout = $stdout, StringIO.new

      PostgresqlTimestampWithZone.connection.execute("CREATE TYPE custom_time_format AS ENUM ('past', 'present', 'future');")

      ActiveRecord::ConnectionAdapters::CockroachDBAdapter::NATIVE_DATABASE_TYPES[:datetimes_as_enum] = { name: "custom_time_format" }
      with_cockroachdb_datetime_type(:datetimes_as_enum) do
        ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime, precision: nil

        assert_equal({ "data_type" => "USER-DEFINED", "udt_name" => "custom_time_format" },
                    PostgresqlTimestampWithZone.connection.execute("select data_type, udt_name from information_schema.columns where column_name = 'times'").to_a.first)
      end
    ensure
      ActiveRecord::ConnectionAdapters::CockroachDBAdapter::NATIVE_DATABASE_TYPES.delete(:datetimes_as_enum)
      ActiveRecord::Migration.new.remove_column :postgresql_timestamp_with_zones, :times, if_exists: true
      ActiveRecord::Base.connection.execute("DROP TYPE IF EXISTS custom_time_format")
      $stdout = original
    end
  end
end
