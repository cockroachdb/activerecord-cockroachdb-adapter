# frozen_string_literal: true

require "cases/migration/helper"

module ActiveRecord
  module CockroachDB
    class Migration
      class ColumnsTest < ActiveRecord::TestCase
        include ActiveRecord::Migration::TestHelper

        self.use_transactional_tests = false

        # This file replaces the same tests that have been excluded from ColumnsTest
        # (see test/excludes/ActiveRecord/Migration/ColumnsTest.rb). New, unsaved
        # records won't have string default values if the default has been changed
        # in the database. This happens because once a column default is changed
        # in CockroachDB, the type information on the value is missing.
        # We can still verify the desired behavior by persisting the test records.
        # When ActiveRecord fetches the records from the database, they'll have
        # their default values.

        def test_change_column_default
          add_column "test_models", "first_name", :string
          connection.change_column_default "test_models", "first_name", "Tester"
          TestModel.reset_column_information

          # Instead of using an unsaved TestModel record, persist one and fetch
          # it from the database to get the new default value for type.

          TestModel.create!
          test_model = TestModel.last
          assert_equal "Tester", test_model.first_name
        end

        def test_change_column_default_with_from_and_to
          add_column "test_models", "first_name", :string
          connection.change_column_default "test_models", "first_name", from: nil, to: "Tester"
          TestModel.reset_column_information

          # Instead of using an unsaved TestModel record, persist one and fetch
          # it from the database to get the new default value for type.

          TestModel.create!
          test_model = TestModel.last
          assert_equal "Tester", test_model.first_name
        end
      end
    end
  end
end
