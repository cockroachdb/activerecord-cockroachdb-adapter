require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "support/schema_dumping_helper"

module CockroachDB
  class PostgresqlNumberTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    class PostgresqlNumber < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table("postgresql_numbers", force: true) do |t|
        t.decimal 'decimal_default'
      end
    end

    teardown do
      @connection.drop_table "postgresql_decimals", if_exists: true
    end

    def test_decimal_values
      record = PostgresqlNumber.new(decimal_default: 111.222)
      assert_equal record.decimal_default, 111.222
    end
  end
end
