require "cases/helper_cockroachdb"

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

  class AdapterTestWithoutTransaction < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class Widget < ActiveRecord::Base
      self.primary_key = "widgetid"
    end

    def setup
      @connection = ActiveRecord::Base.connection
    end

    teardown do
      @connection.drop_table :widgets, if_exists: true
      @connection.exec_query("DROP SEQUENCE IF EXISTS widget_seq")
    end

    # This test replaces the excluded test_reset_empty_table_with_custom_pk. We
    # can run the same assertions, but we have to manually create the table so
    # it has a primary key sequence.
    # See test/excludes/ActiveRecord/AdapterTestWithoutTransaction.rb.
    def test_reset_empty_table_with_custom_pk_sequence
      @connection.exec_query("CREATE SEQUENCE widgets_seq")
      @connection.exec_query("
        CREATE TABLE widgets (
          widgetid INT PRIMARY KEY DEFAULT nextval('widgets_seq'),
          name string
        )
      ")
      assert_equal 1, Widget.create(name: "weather").id
    end
  end
end
