require "cases/helper_cockroachdb"

module CockroachDB
  class Horse < ActiveRecord::Base
  end

  class InvertibleMigrationTest < ActiveRecord::TestCase
    class SilentMigration < ActiveRecord::Migration::Current
      def write(text = "")
        # sssshhhhh!!
      end
    end

    class ChangeColumnDefault1 < SilentMigration
      def change
        create_table("horses") do |t|
          t.column :name, :string, default: "Sekitoba"
        end
      end
    end

    class ChangeColumnDefault2 < SilentMigration
      def change
        change_column_default :horses, :name, from: "Sekitoba", to: "Diomed"
      end
    end

    self.use_transactional_tests = false

    setup do
      @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    end

    teardown do
      %w[horses new_horses].each do |table|
        if ActiveRecord::Base.lease_connection.table_exists?(table)
          ActiveRecord::Base.lease_connection.drop_table(table)
        end
      end
      ActiveRecord::Migration.verbose = @verbose_was
    end

    # This replaces the same test that's been excluded from
    # ActiveRecord::InvertibleMigrationTest. New, unsaved records won't have
    # string default values if the default has been changed in the database.
    # This happens because once a column default is changed in CockroachDB, the
    # type information on the value is missing.
    # We can still verify the desired behavior by persisting the test records.
    # When ActiveRecord fetches the records from the database, they'll have
    # their default values.
    # See test/excludes/ActiveRecord/InvertibleMigrationTest.rb
    def test_migrate_revert_change_column_default
      migration1 = ChangeColumnDefault1.new
      migration1.migrate(:up)
      assert_equal "Sekitoba", Horse.new.name

      # Instead of using an unsaved Horse record, persist one and fetch it from
      # the database to get the new default value for name.
      migration2 = ChangeColumnDefault2.new
      migration2.migrate(:up)
      Horse.reset_column_information
      Horse.create!
      assert_equal "Diomed", Horse.last.name

      # Instead of using an unsaved Horse record, persist one and fetch it from
      # the database to get the new default value for name.
      migration2.migrate(:down)
      Horse.reset_column_information
      Horse.create!
      assert_equal "Sekitoba", Horse.last.name
    end
  end
end
