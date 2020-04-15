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
end
