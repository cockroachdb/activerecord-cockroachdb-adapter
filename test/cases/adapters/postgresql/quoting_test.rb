require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "support/schema_dumping_helper"

module CockroachDB
  class PostgresqlQuotingTest < ActiveRecord::PostgreSQLTestCase
    def setup
      @conn = ActiveRecord::Base.connection
      @raise_int_wider_than_64bit = ActiveRecord.raise_int_wider_than_64bit
    end

    # Replace the original test since numbers are quoted.
    def test_do_not_raise_when_int_is_not_wider_than_64bit
      value = 9223372036854775807
      assert_equal "'9223372036854775807'", @conn.quote(value)

      value = -9223372036854775808
      assert_equal "'-9223372036854775808'", @conn.quote(value)
    end

    # Replace the original test since numbers are quoted.
    def test_do_not_raise_when_raise_int_wider_than_64bit_is_false
      ActiveRecord.raise_int_wider_than_64bit = false
      value = 9223372036854775807 + 1
      assert_equal "'9223372036854775808'", @conn.quote(value)
      ActiveRecord.raise_int_wider_than_64bit = @raise_int_wider_than_64bit
    end
  end
end
