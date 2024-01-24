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
      @schema_migration = ActiveRecord::Base.connection.schema_migration
      @internal_metadata = ActiveRecord::Base.connection.internal_metadata
      ActiveRecord::Base.connection.schema_cache.clear!
    end

    teardown do
      ActiveRecord::Base.table_name_prefix = ""
      ActiveRecord::Base.table_name_suffix = ""

      @schema_migration.create_table
      @schema_migration.delete_all_versions

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

    def test_remove_column_with_if_not_exists_not_set
      migration_a = Class.new(ActiveRecord::Migration::Current) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
        end
      }.new

      migration_b = Class.new(ActiveRecord::Migration::Current) {
        def version; 101 end
        def migrate(x)
          remove_column "people", "last_name"
        end
      }.new

      migration_c = Class.new(ActiveRecord::Migration::Current) {
        def version; 102 end
        def migrate(x)
          remove_column "people", "last_name"
        end
      }.new

      ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
      assert_column Person, :last_name, "migration_a should have added the last_name column on people"

      ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
      assert_no_column Person, :last_name, "migration_b should have dropped the last_name column on people"
      migrator = ActiveRecord::Migrator.new(:up, [migration_c], @schema_migration, @internal_metadata, 102)

      error = assert_raises do
        migrator.migrate
      end

      assert_match(/column \"last_name\" does not exist/, error.message)
    ensure
      Person.reset_column_information
    end
  end

  class BulkAlterTableMigrationsTest < ActiveRecord::TestCase
    def setup
      @original_test = ::BulkAlterTableMigrationsTest.new(name)
      @connection = Person.connection
      @connection.create_table(:delete_me, force: true) { |t| }
      Person.reset_column_information
      Person.reset_sequence_name
    end

    teardown do
      Person.connection.drop_table(:delete_me) rescue nil
    end

    %i(
      test_adding_indexes
      test_removing_index
      test_adding_multiple_columns
      test_changing_index
    ).each do |method_name|
      file, line = ::BulkAlterTableMigrationsTest.instance_method(method_name).source_location
      iter = File.foreach(file)
      (line - 1).times { iter.next }
      indent = iter.next[/\A\s*/]
      content = +""
      content << iter.next until iter.peek == indent + "end\n"
      content['"PostgreSQLAdapter" =>'] = '"CockroachDBAdapter" =>'
      eval(<<-RUBY, binding, __FILE__, __LINE__ + 1)
        def #{method_name}
          #{content}
        end
      RUBY
    end

    private

    %i[
      with_bulk_change_table
      column
      columns
      index
      indexes
    ].each do |method|
      define_method(method) do |*args, &block|
        @original_test.send(method, *args, &block)
      end
    end
  end
end
