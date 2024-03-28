require "cases/helper_cockroachdb"
require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"
require "support/copy_cat"

module CockroachDB
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::PostgreSQLTestCase
      self.use_transactional_tests = false
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.connection
      end

      def teardown
        # use connection without follower_reads and telemetry
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)

        ActiveRecord::Base.establish_connection(database_config)
      end

      def test_database_exists_returns_false_when_the_database_does_not_exist
        [ { database: "non_extant_database", adapter: "postgresql" },
          { database: "non_extant_database", adapter: "cockroachdb" } ].each do |config|
          assert_not ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(config),
                    "expected database #{config[:database]} to not exist"
        end
      end

      def test_database_exists_returns_true_when_the_database_exists
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        assert ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(db_config.configuration_hash),
          "expected database #{db_config.database} to exist"
      end

      def test_using_telemetry_builtin_connects_properly
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)
        database_config[:disable_cockroachdb_telemetry] = false

        ActiveRecord::Base.establish_connection(database_config)
        conn = ActiveRecord::Base.connection
        conn_config = conn.instance_variable_get("@config")

        assert_equal(false, conn_config[:disable_cockroachdb_telemetry])
      end

      def test_using_follower_reads_connects_properly
        database_config = { "use_follower_reads_for_type_introspection": true, "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        database_config.update(ar_config.configuration_hash)

        ActiveRecord::Base.establish_connection(database_config)
        conn = ActiveRecord::Base.connection
        conn_config = conn.instance_variable_get("@config")

        assert conn_config[:use_follower_reads_for_type_introspection]
      end

      # OVERRIDE: CockroachDB adds parentheses around the WHERE clause's content.
      def test_partial_index_on_column_named_like_keyword
        with_example_table('id serial primary key, number integer, "primary" boolean') do
          @connection.add_index "ex", "id", name: "partial", where: "primary" # "primary" is a keyword
          index = @connection.indexes("ex").find { |idx| idx.name == "partial" }
          assert_equal '("primary")', index.where
        end
      end

      # OVERRIDE: Different behaviour between PostgreSQL and CockroachDB.
      def test_invalid_index
        with_example_table do
          @connection.exec_query("INSERT INTO ex (number) VALUES (1), (1)")
          error = assert_raises(ActiveRecord::RecordNotUnique) do
            @connection.add_index(:ex, :number, unique: true, algorithm: :concurrently, name: :invalid_index)
          end
          assert_match(/duplicate key value violates unique constraint/, error.message)
          assert_equal @connection.pool, error.connection_pool

          # In CRDB this tests won't create the index at all.
          assert_not @connection.index_exists?(:ex, :number, name: :invalid_index)
        end
      end

      # OVERRIDE: the `default_sequence_name` is `nil`, let's `to_s` it
      #   for a fair comparison.
      CopyCat.copy_methods(self, ActiveRecord::ConnectionAdapters::PostgreSQLAdapterTest,
        :test_pk_and_sequence_for,
        :test_pk_and_sequence_for_with_non_standard_primary_key
      ) do
        attr_accessor :already_updated
        def on_send(node)
          return super unless node in [:send, _, :default_sequence_name, [:str, "ex"], [:str, "id"|"code"]]

          raise "The source code must have changed" if already_updated
          already_updated ||= :yes
          insert_after(node.loc.expression, ".to_s")
        end
      end

      private

      CopyCat.copy_methods(self, ActiveRecord::ConnectionAdapters::PostgreSQLAdapterTest,
        :with_example_table
      )
    end
  end
end
