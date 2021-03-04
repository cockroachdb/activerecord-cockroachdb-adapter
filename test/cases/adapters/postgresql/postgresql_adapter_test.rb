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

      def test_database_exists_returns_false_when_the_database_does_not_exist
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        config = db_config.configuration_hash.dup
        config[:database] = "non_extant_database"
        assert_not ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(config),
                   "expected database #{config[:database]} to not exist"
      end

      def test_database_exists_returns_true_when_the_database_exists
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        assert ActiveRecord::ConnectionAdapters::CockroachDBAdapter.database_exists?(db_config.configuration_hash),
          "expected database #{db_config.database} to exist"
      end
    end
  end
end
