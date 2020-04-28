# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module CockroachDB
    class Migration
      class ChangeSchemaTest < ActiveRecord::TestCase
        attr_reader :connection, :table_name

        self.use_transactional_tests = false

        def setup
          super
          @connection = ActiveRecord::Base.connection
          @table_name = :testings
        end

        teardown do
          connection.drop_table :testings rescue nil
          ActiveRecord::Base.primary_key_prefix_type = nil
          ActiveRecord::Base.clear_cache!
        end

        # This test is identical to the one in Rails, except here we are running
        # it with transactions turned off so that we can properly assert on
        # database changes. See https://www.cockroachlabs.com/docs/v19.2/transactions.html
        def test_drop_table_if_exists
          connection.create_table(:testings)
          assert connection.table_exists?(:testings)
          connection.drop_table(:testings, if_exists: true)
          assert_not connection.table_exists?(:testings)
        end

        # This test is identical to the one in Rails, except here we are running
        # it with transactions turned off so that we can properly assert on
        # database changes. See https://www.cockroachlabs.com/docs/v19.2/transactions.html
        def test_keeping_default_and_notnull_constraints_on_change
          connection.create_table :testings do |t|
            t.column :title, :string
          end
          person_klass = Class.new(ActiveRecord::Base)
          person_klass.table_name = "testings"

          person_klass.connection.add_column "testings", "wealth", :integer, null: false, default: 99
          person_klass.reset_column_information
          assert_equal 99, person_klass.column_defaults["wealth"]
          assert_equal false, person_klass.columns_hash["wealth"].null
          assert_nothing_raised { person_klass.connection.execute("insert into testings (title) values ('tester')") }

          # change column default to see that column doesn't lose its not null definition
          person_klass.connection.change_column_default "testings", "wealth", 100
          person_klass.reset_column_information
          assert_equal 100, person_klass.column_defaults["wealth"]
          assert_equal false, person_klass.columns_hash["wealth"].null

          # rename column to see that column doesn't lose its not null and/or default definition
          person_klass.connection.rename_column "testings", "wealth", "money"
          person_klass.reset_column_information
          assert_nil person_klass.columns_hash["wealth"]
          assert_equal 100, person_klass.column_defaults["money"]
          assert_equal false, person_klass.columns_hash["money"].null

          # change column
          person_klass.connection.change_column "testings", "money", :integer, null: false, default: 1000
          person_klass.reset_column_information
          assert_equal 1000, person_klass.column_defaults["money"]
          assert_equal false, person_klass.columns_hash["money"].null

          # change column, make it nullable and clear default
          person_klass.connection.change_column "testings", "money", :integer, null: true, default: nil
          person_klass.reset_column_information
          assert_nil person_klass.columns_hash["money"].default
          assert_equal true, person_klass.columns_hash["money"].null

          # change_column_null, make it not nullable and set null values to a default value
          person_klass.connection.execute("UPDATE testings SET money = NULL")
          person_klass.connection.change_column_null "testings", "money", false, 2000
          person_klass.reset_column_information
          assert_nil person_klass.columns_hash["money"].default
          assert_equal false, person_klass.columns_hash["money"].null
          assert_equal 2000, connection.select_values("SELECT money FROM testings").first.to_i
        end

        # This test is identical to the one in Rails, except here we are running
        # it with transactions turned off so that we can properly assert on
        # database changes. See https://www.cockroachlabs.com/docs/v19.2/transactions.html
        def test_change_column_null
          testing_table_with_only_foo_attribute do
            notnull_migration = Class.new(ActiveRecord::Migration::Current) do
              def change
                change_column_null :testings, :foo, false
              end
            end
            notnull_migration.new.suppress_messages do
              notnull_migration.migrate(:up)
              assert_equal false, connection.columns(:testings).find { |c| c.name == "foo" }.null
              notnull_migration.migrate(:down)
              assert connection.columns(:testings).find { |c| c.name == "foo" }.null
            end
          end
        end

        def test_create_table_with_limits
          connection.create_table :testings do |t|
            t.column :foo, :string, limit: 255

            t.column :default_int, :integer

            t.column :one_int,    :integer, limit: 1
            t.column :four_int,   :integer, limit: 4
            t.column :eight_int,  :integer, limit: 8
          end

          columns = connection.columns(:testings)
          foo = columns.detect { |c| c.name == "foo" }
          assert_equal 255, foo.limit

          default = columns.detect { |c| c.name == "default_int" }
          one     = columns.detect { |c| c.name == "one_int"     }
          four    = columns.detect { |c| c.name == "four_int"    }
          eight   = columns.detect { |c| c.name == "eight_int"   }

          assert_equal "bigint", default.sql_type #This differs from PG, whose default type is integer
          assert_equal "smallint", one.sql_type
          assert_equal "integer", four.sql_type
          assert_equal "bigint", eight.sql_type
        end
      end
    end
  end
end
