# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module CockroachDB
    class Migration
      class ReferencesForeignKeyTest < ActiveRecord::TestCase
        # These tests are identical to the ones found in Rails, save for the fact
        # that transactions are turned off for test runs. It is necessary to disable
        # transactional tests in order to assert on schema changes due to how
        # CockroachDB handles transactions.
        self.use_transactional_tests = false

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table(:testing_parents, force: true)
        end

        teardown do
          @connection.drop_table "testings", if_exists: true
          @connection.drop_table "testing_parents", if_exists: true
        end

        test "foreign keys can be created while changing the table" do
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            t.references :testing_parent, foreign_key: true
          end

          fk = @connection.foreign_keys("testings").first
          assert_equal "testings", fk.from_table
          assert_equal "testing_parents", fk.to_table
        end

        test "foreign keys accept options when changing the table" do
          @connection.change_table :testing_parents do |t|
            t.references :other, index: { unique: true }
          end
          @connection.create_table :testings
          @connection.change_table :testings do |t|
            t.references :testing_parent, foreign_key: { primary_key: :other_id }
          end

          fk = @connection.foreign_keys("testings").find { |k| k.to_table == "testing_parents" }
          assert_equal "other_id", fk.primary_key
        end

        test "foreign key column can be removed" do
          @connection.create_table :testings do |t|
            t.references :testing_parent, index: true, foreign_key: true
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_reference :testings, :testing_parent, foreign_key: true
          end
        end

        test "removing column removes foreign key" do
          @connection.create_table :testings do |t|
            t.references :testing_parent, index: true, foreign_key: true
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_column :testings, :testing_parent_id
          end
        end

        test "foreign key methods respect pluralize_table_names" do
          begin
            original_pluralize_table_names = ActiveRecord::Base.pluralize_table_names
            ActiveRecord::Base.pluralize_table_names = false
            @connection.create_table :testing
            @connection.change_table :testing_parents do |t|
              t.references :testing, foreign_key: true
            end

            fk = @connection.foreign_keys("testing_parents").first
            assert_equal "testing_parents", fk.from_table
            assert_equal "testing", fk.to_table

            assert_difference "@connection.foreign_keys('testing_parents').size", -1 do
              @connection.remove_reference :testing_parents, :testing, foreign_key: true
            end
          ensure
            ActiveRecord::Base.pluralize_table_names = original_pluralize_table_names
            @connection.drop_table "testing", if_exists: true
          end
        end

        test "multiple foreign keys can be removed to the selected one" do
          @connection.create_table :testings do |t|
            t.references :parent1, foreign_key: { to_table: :testing_parents }
            t.references :parent2, foreign_key: { to_table: :testing_parents }
          end

          assert_difference "@connection.foreign_keys('testings').size", -1 do
            @connection.remove_reference :testings, :parent1, foreign_key: { to_table: :testing_parents }
          end

          fks = @connection.foreign_keys("testings").sort_by(&:column)

          fk_definitions = fks.map { |fk| [fk.from_table, fk.to_table, fk.column] }
          assert_equal([["testings", "testing_parents", "parent2_id"]], fk_definitions)
        end
      end
    end
  end
