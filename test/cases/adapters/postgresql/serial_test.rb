require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "support/schema_dumping_helper"

module CockroachDB
  class PostgresqlSerialTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    class PostgresqlSerial < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table "postgresql_serials", force: true do |t|
        t.serial :seq

        # Instead of creating this column with a sequence default, we'll create
        # it with a unique_rowid() default. This better matches the behavior in
        # CockroachDB.
        t.integer :serials_id, default: -> { "unique_rowid()" }
      end
    end

    teardown do
      @connection.drop_table "postgresql_serials", if_exists: true
    end

    # This replaces the same test that's been excluded from
    # PostgresqlSerialTest. The column's type is integer, but it's sql_type is
    # bigint because CockroachDB's integers are bigints.
    # See test/excludes/PostgresqlSerialTest.rb
    def test_serial_column
      column = PostgresqlSerial.columns_hash["seq"]
      assert_equal :integer, column.type
      assert_equal "bigint", column.sql_type
      assert_predicate column, :serial?
    end

    # This replaces the same test that's been excluded from
    # PostgresqlSerialTest. The column's type is integer, but it's sql_type is
    # bigint because CockroachDB's integers are bigints. The column is also
    # serial? because it uses the same default function that serial columns use.
    # See test/excludes/PostgresqlSerialTest.rb
    def test_not_serial_column
      column = PostgresqlSerial.columns_hash["serials_id"]
      assert_equal :integer, column.type
      assert_equal "bigint", column.sql_type
      assert_predicate column, :serial?
    end

    # This replaces the same test that's been excluded from
    # PostgresqlSerialTest. Although the seq column was created as a serial
    # column, the dump will include it as a bigserial column. That's because
    # serial columns are backed by integer columns, and integer columns are
    # bigints in CockroachDB.
    # See test/excludes/PostgresqlSerialTest.rb
    def test_schema_dump_with_shorthand
      output = dump_table_schema "postgresql_serials"
      assert_match %r{t\.bigserial\s+"seq",\s+null: false$}, output
    end

    # This replaces the same test that's been excluded from
    # PostgresqlSerialTest. The serials_id column wasn't created as a serial
    # column, but the dump will include it as such because it has the same
    # default function has a serial column.
    # See test/excludes/PostgresqlSerialTest.rb
    def test_schema_dump_with_not_serial
      output = dump_table_schema "postgresql_serials"
      assert_match %r{t\.bigserial\s+"serials_id"$}, output
    end
  end

  class PostgresqlBigSerialTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    class PostgresqlBigSerial < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.connection
      @connection.create_table "postgresql_big_serials", force: true do |t|
        t.bigserial :seq

        # Instead of creating this column with a sequence default, we'll create
        # it with a unique_rowid() default. This better matches the behavior in
        # CockroachDB.
        t.bigint :serials_id, default: -> { "unique_rowid()" }
      end
    end

    teardown do
      @connection.drop_table "postgresql_big_serials", if_exists: true
    end

    # This replaces the same test that's been excluded from
    # PostgresqlBigSerialTest. We can run it here because the setup has been
    # fixed.
    # See test/excluded/PostgresqlBigSerialTest.rb
    def test_bigserial_column
      column = PostgresqlBigSerial.columns_hash["seq"]
      assert_equal :integer, column.type
      assert_equal "bigint", column.sql_type
      assert_predicate column, :serial?
    end

    # This replaces the same test that's been excluded from
    # PostgresqlBigSerialTest. The column is serial? because it uses the same
    # default function that serial columns use.
    # See test/excludes/PostgresqlBigSerialTest.rb
    def test_not_bigserial_column
      column = PostgresqlBigSerial.columns_hash["serials_id"]
      assert_equal :integer, column.type
      assert_equal "bigint", column.sql_type
      assert_predicate column, :serial?
    end

    # This replaces the same test that's been excluded from
    # PostgresqlBigSerialTest. We can run it here because the setup has been
    # fixed.
    # See test/excluded/PostgresqlBigSerialTest.rb
    def test_schema_dump_with_shorthand
      output = dump_table_schema "postgresql_big_serials"
      assert_match %r{t\.bigserial\s+"seq",\s+null: false$}, output
    end

    # This replaces the same test that's been excluded from
    # PostgresqlBigSerialTest. The serials_id column wasn't created as a serial
    # column, but the dump will include it as such because it has the same
    # default function has a serial column.
    # See test/excluded/PostgresqlBigSerialTest.rb
    def test_schema_dump_with_not_bigserial
      output = dump_table_schema "postgresql_big_serials"
      assert_match %r{t\.bigserial\s+"serials_id"$}, output
    end
  end

  module SequenceNameDetectionTestCases
    class CollidedSequenceNameTest < ActiveRecord::PostgreSQLTestCase
      include SchemaDumpingHelper

      def setup
        @connection = ActiveRecord::Base.connection
        @connection.create_table :foo_bar, force: true do |t|
          t.serial :baz_id
        end
        @connection.create_table :foo, force: true do |t|
          t.serial :bar_id
          t.bigserial :bar_baz_id
        end
      end

      def teardown
        @connection.drop_table :foo_bar, if_exists: true
        @connection.drop_table :foo, if_exists: true
      end

      # This replaces the same test that's been excluded from
      # SequenceNameDetectionTestCases::CollidedSequenceNameTest. Although
      # bar_id was created as a serial column, it will get dumped as a bigserial
      # column. Serial columns are backed by integer columns, and integer
      # columns are bigints in CockroachDB.
      # See test/excludes/SequenceNameDetectionTestCases/CollidedSequenceNameTest.rb
      def test_schema_dump_with_collided_sequence_name
        output = dump_table_schema "foo"
        assert_match %r{t\.bigserial\s+"bar_id",\s+null: false$}, output
        assert_match %r{t\.bigserial\s+"bar_baz_id",\s+null: false$}, output
      end
    end

    class LongerSequenceNameDetectionTest < ActiveRecord::PostgreSQLTestCase
      include SchemaDumpingHelper

      def setup
        @table_name = "long_table_name_to_test_sequence_name_detection_for_serial_cols"
        @connection = ActiveRecord::Base.connection
        @connection.create_table @table_name, force: true do |t|
          t.serial :seq
          t.bigserial :bigseq
        end
      end

      def teardown
        @connection.drop_table @table_name, if_exists: true
      end

      # This replaces the same test that's been excluded from
      # SequenceNameDetectionTestCases::LongerSequenceNameDetectionTest.
      # Although seq was created as a serial column, it will get dumped as a bigserial
      # column. Serial columns are backed by integer columns, and integer
      # columns are bigints in CockroachDB.
      # See test/excludes/SequenceNameDetectionTestCases/LongerSequenceNameDetectionTest.rb
      def test_schema_dump_with_long_table_name
        output = dump_table_schema @table_name
        assert_match %r{create_table "#{@table_name}", force: :cascade}, output
        assert_match %r{t\.bigserial\s+"seq",\s+null: false$}, output
        assert_match %r{t\.bigserial\s+"bigseq",\s+null: false$}, output
      end
    end
  end
end
