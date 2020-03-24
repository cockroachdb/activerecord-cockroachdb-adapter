require "cases/helper_cockroachdb"
require "cases/helper"

module CockroachDB
  class AdapterTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    # This replaces the same test that's been excluded from
    # ActiveRecord::AdapterTest. We can run it here with
    # use_transactional_tests set to false.
    # See test/excludes/ActiveRecord/AdapterTest.rb.
    def test_indexes
      idx_name = "accounts_idx"

      indexes = @connection.indexes("accounts")
      assert_empty indexes

      @connection.add_index :accounts, :firm_id, name: idx_name
      indexes = @connection.indexes("accounts")
      assert_equal "accounts", indexes.first.table
      assert_equal idx_name, indexes.first.name
      assert !indexes.first.unique
      assert_equal ["firm_id"], indexes.first.columns
    ensure
      @connection.remove_index(:accounts, name: idx_name) rescue nil
    end

    # This replaces the same test that's been excluded from
    # ActiveRecord::AdapterTest. We can run it here with
    # use_transactional_tests set to false.
    # See test/excludes/ActiveRecord/AdapterTest.rb.
    def test_remove_index_when_name_and_wrong_column_name_specified
      index_name = "accounts_idx"

      @connection.add_index :accounts, :firm_id, name: index_name
      assert_raises ArgumentError do
        @connection.remove_index :accounts, name: index_name, column: :wrong_column_name
      end
    ensure
      @connection.remove_index(:accounts, name: index_name)
    end
  end
end
