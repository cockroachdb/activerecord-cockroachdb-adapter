require "cases/helper_cockroachdb"
require "cases/helper"
require "support/ddl_helper"
require "support/connection_helper"

module CockroachDB
  module ConnectionAdapters
    class PostgreSQLAdapterTest < ActiveRecord::PostgreSQLTestCase
      self.use_transactional_tests = false
      include DdlHelper
      include ConnectionHelper

      def setup
        @connection = ActiveRecord::Base.connection
        @connection_handler = ActiveRecord::Base.connection_handler
      end

      def teardown
        # use connection without follower_reads
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations["arunit"]
        database_config.update(ar_config)

        ActiveRecord::Base.establish_connection(database_config)
      end

      def test_database_exists_returns_false_when_the_database_does_not_exist
        db_config = ActiveRecord::Base.configurations["arunit"]
        config = db_config.dup
        config[:database] = "non_extant_database"
        db_exists = begin
                      !!ActiveRecord::Base.postgresql_connection(config)
                    rescue ActiveRecord::ActiveRecordError => error
                      if error.message.include?("does not exist")
                        false
                      else
                        raise
                      end
                    end
        assert_not db_exists, "expected database #{config[:database]} to not exist"
      end

      def test_database_exists_returns_true_when_the_database_exists
        db_config = ActiveRecord::Base.configurations["arunit"]
        db_exists = begin
                      !!ActiveRecord::Base.postgresql_connection(db_config)
                    rescue ActiveRecord::ActiveRecordError => error
                      if error.message.include?("does not exist")
                        false
                      else
                        raise
                      end
                    end
        assert db_exists, "expected database #{db_config[:database]} to exist"
      end

      def test_using_telemetry_builtin_connects_properly
        database_config = { "adapter" => "cockroachdb", "database" => "activerecord_unittest" }
        ar_config = ActiveRecord::Base.configurations["arunit"]
        database_config.update(ar_config)
        database_config[:disable_cockroachdb_telemetry] = false

        ActiveRecord::Base.establish_connection(database_config)
        conn = ActiveRecord::Base.connection
        conn_config = conn.instance_variable_get("@config")

        assert_equal(false, conn_config[:disable_cockroachdb_telemetry])
      end
    end
  end
end
