require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "support/schema_dumping_helper"
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

  class PrimaryKeyIntegerTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    self.use_transactional_tests = false

    class Widget < ActiveRecord::Base
    end

    setup do
      @connection = ActiveRecord::Base.connection
      @pk_type = :serial
    end

    teardown do
      @connection.drop_table :widgets, if_exists: true
    end

    # This replaces the same test that's been excluded from
    # PrimaryKeyIntegerTest. In PostgreSQL, serial columns are backed by integer
    # columns. They're also backed by integer columns in CockroachDB, but
    # integer columns are the same size as PostgreSQL's bigints. Therefore, we
    # change the final assertion to verify the serial column is a bigint.
    # See test/excludes/PrimaryKeyIntegerTest.rb
    test "primary key column type with serial/integer" do
      @connection.create_table(:widgets, id: @pk_type, force: true)
      column = @connection.columns(:widgets).find { |c| c.name == "id" }
      assert_equal :integer, column.type
      assert_predicate column, :bigint?
    end

    # This replaces the same test that's been excluded from
    # PrimaryKeyIntegerTest. Although the widgets table is created with a serial
    # primary key, that info will not be included in the schema dump.
    # CockroachDB serial and bigserial columns are really bigserial columns, and
    # ActiveRecord defaults to bigserial primary keys. Therefore, nothing about
    # the id primary key will be in the widgets schema dump.
    # See test/excludes/PrimaryKeyIntegerTest.rb
    test "schema dump primary key with serial/integer" do
      @connection.create_table(:widgets, id: @pk_type, force: true)
      schema = dump_table_schema "widgets"
      assert_match %r{create_table "widgets", }, schema
    end
  end

  class PrimaryKeyIntegerNilDefaultTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    self.use_transactional_tests = false

    def setup
      @connection = ActiveRecord::Base.connection
    end

    def teardown
      @connection.drop_table :int_defaults, if_exists: true
    end

    # This replaces the same test that's been excluded from
    # PrimaryKeyIntegerNilDefaultTest. int_defaults is created with an integer
    # primary key, and integer columns are bigints in CockroachDB. Therefore,
    # the schema dump will include the primary key as :bigint.
    # See test/excludes/PrimaryKeyIntegerNilDefaultTest.rb
    def test_schema_dump_primary_key_integer_with_default_nil
      skip if current_adapter?(:SQLite3Adapter)
      @connection.create_table(:int_defaults, id: :integer, default: nil, force: true)
      schema = dump_table_schema "int_defaults"
      assert_match %r{create_table "int_defaults", id: :bigint, default: nil}, schema
    end
  end
end
