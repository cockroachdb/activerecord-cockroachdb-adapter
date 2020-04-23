require "cases/helper_cockroachdb"

module CockroachDB
  class BulkAlterTableMigrationsTest < ActiveRecord::TestCase
    def setup
      @connection = Person.connection
      @connection.create_table(:delete_me, force: true) { |t| }
      Person.reset_column_information
      Person.reset_sequence_name
    end

    teardown do
      Person.connection.drop_table(:delete_me) rescue nil
    end

    def test_adding_multiple_columns
      classname = ActiveRecord::Base.connection.class.name[/[^:]*$/]
      expected_query_count = {
        "CockroachDBAdapter" => 2, # one for bulk change, one for comment
      }.fetch(classname) {
          raise "need an expected query count for #{classname}"
        }

        assert_queries(expected_query_count) do
          with_bulk_change_table do |t|
            t.column :name, :string
            t.string :qualification, :experience
            t.integer :age, default: 0
            t.date :birthdate, comment: "This is a comment"
            t.timestamps null: true
          end
        end

        assert_equal 8, columns.size
        [:name, :qualification, :experience].each { |s| assert_equal :string, column(s).type }
        assert_equal "0", column(:age).default
        assert_equal "This is a comment", column(:birthdate).comment
    end

    def test_changing_columns
      with_bulk_change_table do |t|
        t.string :name
        t.date :birthdate
      end

      assert ! column(:name).default
      assert_equal :date, column(:birthdate).type

      classname = ActiveRecord::Base.connection.class.name[/[^:]*$/]
      expected_query_count = {
        "CockroachDBAdapter" => 3, # one query for columns, one for bulk change, one for comment
      }.fetch(classname) {
          raise "need an expected query count for #{classname}"
        }

        assert_queries(expected_query_count, ignore_none: true) do
          with_bulk_change_table do |t|
            t.change :name, :string, default: "NONAME"
            t.change :birthdate, :datetime, comment: "This is a comment"
          end
        end

        assert_equal "NONAME", column(:name).default
        assert_equal :datetime, column(:birthdate).type
        assert_equal "This is a comment", column(:birthdate).comment
    end
  end

  def test_adding_indexes
    with_bulk_change_table do |t|
      t.string :username
      t.string :name
      t.integer :age
    end

    classname = ActiveRecord::Base.connection.class.name[/[^:]*$/]
    expected_query_count = {
      "CockroachDBAdapter" => 2,
    }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries(expected_query_count) do
        with_bulk_change_table do |t|
          t.index :username, unique: true, name: :awesome_username_index
          t.index [:name, :age]
        end
      end
  end

  private
    def with_bulk_change_table
      # Reset columns/indexes cache as we're changing the table
      @columns = @indexes = nil

      Person.connection.change_table(:delete_me, bulk: true) do |t|
        yield t
      end
    end

    def column(name)
      columns.detect { |c| c.name == name.to_s }
    end

    def columns
      @columns ||= Person.connection.columns("delete_me")
    end

    def index(name)
      indexes.detect { |i| i.name == name.to_s }
    end

    def indexes
      @indexes ||= Person.connection.indexes("delete_me")
    end
end
