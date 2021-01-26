require "cases/helper_cockroachdb"
require "models/person"

class Reminder < ActiveRecord::Base; end unless Object.const_defined?(:Reminder)
class Thing < ActiveRecord::Base; end unless Object.const_defined?(:Thing)
module CockroachDB
  class MigrationTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :people

    def setup
      super
      %w(reminders people_reminders prefix_reminders_suffix p_things_s).each do |table|
        Reminder.connection.drop_table(table) rescue nil
      end
      Reminder.reset_column_information
      @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
      ActiveRecord::Base.connection.schema_cache.clear!
    end

    teardown do
      ActiveRecord::Base.table_name_prefix = ""
      ActiveRecord::Base.table_name_suffix = ""

      ActiveRecord::SchemaMigration.create_table
      ActiveRecord::SchemaMigration.delete_all

      %w(things awesome_things prefix_things_suffix p_awesome_things_s).each do |table|
        Thing.connection.drop_table(table) rescue nil
      end
      Thing.reset_column_information

      %w(reminders people_reminders prefix_reminders_suffix).each do |table|
        Reminder.connection.drop_table(table) rescue nil
      end
      Reminder.reset_table_name
      Reminder.reset_column_information

      %w(last_name key bio age height wealth birthday favorite_day
       moment_of_truth male administrator funny).each do |column|
        Person.connection.remove_column("people", column) rescue nil
      end
      Person.connection.remove_column("people", "first_name") rescue nil
      Person.connection.remove_column("people", "middle_name") rescue nil
      Person.connection.add_column("people", "first_name", :string)
      Person.reset_column_information

      ActiveRecord::Migration.verbose = @verbose_was
    end

    def test_create_table_with_query
      Person.connection.create_table :table_from_query_testings, as: "SELECT id FROM people WHERE id = 1"

      columns = Person.connection.columns(:table_from_query_testings)
      assert_equal [1], Person.connection.select_values("SELECT * FROM table_from_query_testings")
      assert_equal 2, columns.length # columns.length equals 1 in PG since this query does not create a primary key
      assert_equal "id", columns.first.name
    ensure
      Person.connection.drop_table :table_from_query_testings rescue nil
    end

    def test_create_table_with_query_from_relation
      Person.connection.create_table :table_from_query_testings, as: Person.select(:id).where(id: 1)

      columns = Person.connection.columns(:table_from_query_testings)
      assert_equal [1], Person.connection.select_values("SELECT * FROM table_from_query_testings")
      assert_equal 2, columns.length # columns.length equals 1 in PG since this query does not create a primary key
      assert_equal "id", columns.first.name
    ensure
      Person.connection.drop_table :table_from_query_testings rescue nil
    end
  end

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
        "CockroachDBAdapter" => 8, # 5 new explicit columns, 2 for created_at/updated_at, 1 comment
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
end
