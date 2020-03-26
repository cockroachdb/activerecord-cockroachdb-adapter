require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "models/topic"
require "models/mixed_case_monkey"

module CockroachDB
  class PrimaryKeysTest < ActiveRecord::TestCase
    fixtures :mixed_case_monkeys, :topics

    # This replaces the same test that's been excluded from PrimaryKeysTest. We
    # run it here without an assertion on column.default_function because it
    # will always be unique_rowid() in CockroachDB.
    # See test/excludes/PrimaryKeysTest.rb
    def test_serial_with_quoted_sequence_name
      column = MixedCaseMonkey.columns_hash[MixedCaseMonkey.primary_key]
      assert_predicate column, :serial?
    end

    # This replaces the same test that's been excluded from PrimaryKeysTest. We
    # run it here without an assertion on column.default_function because it
    # will always be unique_rowid() in CockroachDB.
    # See test/excludes/PrimaryKeysTest.rb
    def test_serial_with_unquoted_sequence_name
      column = Topic.columns_hash[Topic.primary_key]
      assert_predicate column, :serial?
    end
  end
end
