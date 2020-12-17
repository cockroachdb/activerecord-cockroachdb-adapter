require "cases/helper_cockroachdb"
require "models/binary"
require "models/developer"
require "models/post"
require "models/author"

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

  class AdapterForeignKeyTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :fk_test_has_pk

    def before_setup
      conn = ActiveRecord::Base.connection

      conn.drop_table :fk_test_has_fk, if_exists: true
      conn.drop_table :fk_test_has_pk, if_exists: true

      conn.create_table :fk_test_has_pk, primary_key: "pk_id", force: :cascade do |t|
      end

      conn.create_table :fk_test_has_fk, force: true do |t|
        t.references :fk, null: false
        t.foreign_key :fk_test_has_pk, column: "fk_id", name: "fk_name", primary_key: "pk_id"
      end

      conn.execute "INSERT INTO fk_test_has_pk (pk_id) VALUES (1)"
    end

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def test_foreign_key_violations_are_translated_to_specific_exception_with_validate_false
      klass_has_fk = Class.new(ActiveRecord::Base) do
        self.table_name = "fk_test_has_fk"
      end

      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        has_fk = klass_has_fk.new
        has_fk.fk_id = 1231231231
        has_fk.save(validate: false)
      end

      assert_not_nil error.cause
    end

    # This is override to prevent an intermittent error
    # Table fk_test_has_pk has constrain droped and not created back
    def test_foreign_key_violations_on_insert_are_translated_to_specific_exception
      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        insert_into_fk_test_has_fk
      end

      assert_not_nil error.cause
    end

    # This is override to prevent an intermittent error
    # Table fk_test_has_pk has constrain droped and not created back
    def test_foreign_key_violations_on_delete_are_translated_to_specific_exception
      insert_into_fk_test_has_fk fk_id: 1

      error = assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.execute "DELETE FROM fk_test_has_pk WHERE pk_id = 1"
      end

      assert_not_nil error.cause
    end

    private

    def insert_into_fk_test_has_fk(fk_id: 0)
      # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
      if @connection.prefetch_primary_key?
        id_value = @connection.next_sequence_value(@connection.default_sequence_name("fk_test_has_fk", "id"))
        @connection.execute "INSERT INTO fk_test_has_fk (id,fk_id) VALUES (#{id_value},#{fk_id})"
      else
        @connection.execute "INSERT INTO fk_test_has_fk (fk_id) VALUES (#{fk_id})"
      end
    end
  end

  class AdapterTestWithoutTransaction < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :posts, :authors, :author_addresses

    class Widget < ActiveRecord::Base
      self.primary_key = "widgetid"
    end

    def setup
      @connection = ActiveRecord::Base.connection
    end

    teardown do
      @connection.drop_table :widgets, if_exists: true
      @connection.exec_query("DROP SEQUENCE IF EXISTS widget_seq")
      @connection.exec_query("DROP SEQUENCE IF EXISTS widgets_seq")
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

    def test_truncate_tables
      assert_operator Post.count, :>, 0
      assert_operator Author.count, :>, 0
      assert_operator AuthorAddress.count, :>, 0

      @connection.truncate_tables("author_addresses", "authors", "posts")

      assert_equal 0, Post.count
      assert_equal 0, Author.count
      assert_equal 0, AuthorAddress.count
    ensure
      reset_fixtures("author_addresses", "authors", "posts")
    end

    def test_truncate_tables_with_query_cache
      @connection.enable_query_cache!

      assert_operator Post.count, :>, 0
      assert_operator Author.count, :>, 0
      assert_operator AuthorAddress.count, :>, 0

      @connection.truncate_tables("author_addresses", "authors", "posts")

      assert_equal 0, Post.count
      assert_equal 0, Author.count
      assert_equal 0, AuthorAddress.count
    ensure
      reset_fixtures("author_addresses", "authors", "posts")
      @connection.disable_query_cache!
    end

    private

    def reset_fixtures(*fixture_names)
      ActiveRecord::FixtureSet.reset_cache

      fixture_names.each do |fixture_name|
        ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, fixture_name)
      end
    end
  end
end
