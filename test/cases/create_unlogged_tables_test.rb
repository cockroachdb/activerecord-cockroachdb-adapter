require "cases/helper_cockroachdb"

require "cases/helper"
require "models/post"
require "models/comment"
require "models/author"
require "models/rating"
require "models/categorization"
require "support/schema_dumping_helper"

module ActiveRecord
  module CockroachDB
    class UnloggedTablesTest < ActiveRecord::PostgreSQLTestCase
      include SchemaDumpingHelper

      TABLE_NAME = "things"
      LOGGED_FIELD = "relpersistence"
      LOGGED_QUERY = "SELECT #{LOGGED_FIELD} FROM pg_class WHERE relname = '#{TABLE_NAME}'"
      LOGGED = "p"
      UNLOGGED = "u"
      TEMPORARY = "t"

      class Thing < ActiveRecord::Base
        self.table_name = TABLE_NAME
      end

      def setup
        @connection = ActiveRecord::Base.connection
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = false
      end

      teardown do
        @connection.drop_table TABLE_NAME, if_exists: true
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = false
      end

      # Cockroachdb has an issue about `pg_class`
      # https://github.com/cockroachdb/cockroach/issues/56656
      # This override can be removed after it be fix
      def test_unlogged_in_test_environment_when_unlogged_setting_enabled
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true

        @connection.create_table(TABLE_NAME) do |t|
        end
        assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], LOGGED
      end

      # Cockroachdb has an issue about `pg_class`
      # https://github.com/cockroachdb/cockroach/issues/56656
      # This override can be removed after it be fix
      def test_gracefully_handles_temporary_tables
        @connection.execute("SET experimental_enable_temp_tables = 'on';")
        @connection.create_table(TABLE_NAME, temporary: true) do |t|
        end

        assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], LOGGED
      end
    end
  end
end