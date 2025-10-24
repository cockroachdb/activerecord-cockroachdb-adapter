require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "support/schema_dumping_helper"

module CockroachDB
  class DefaultExpressionTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    # This replaces the same test that's been excluded from
    # PostgresqlDefaultExpressionTest. The assertions have updated to match
    # against CockroachDB's current_date() and current_timestamp() functions.
    # See test/excludes/PostgresqlDefaultExpressionTest.rb.
    test "schema dump includes default expression" do
      output = dump_table_schema("defaults")

      assert_match %r/t\.date\s+"modified_date",\s+default: -> { \"current_date\(\)\" }/, output
      assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "current_timestamp\(\)" }/, output

      assert_match %r/t\.date\s+"modified_date_function",\s+default: -> { "now\(\)" }/, output
      assert_match %r/t\.datetime\s+"modified_time_function",\s+default: -> { "now\(\)" }/, output
    end
  end

  class DefaultNumbersTest < ActiveRecord::TestCase
    class DefaultNumber < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :default_numbers do |t|
        t.decimal :decimal_number, precision: 32, scale: 16, default: 0
      end
    end

    teardown do
      @connection.drop_table :default_numbers, if_exists: true
    end

    def test_default_decimal_zero_with_large_scale
      record = DefaultNumber.new
      assert_equal 0.0, record.decimal_number
      assert_equal 0.0, record.decimal_number_before_type_cast
    end
  end
end
