# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "support/schema_dumping_helper"


module ActiveRecord
  module Cockroach
    class Migration
      class UniqueConstraintTest < ActiveRecord::TestCase

        setup do
          @connection = ActiveRecord::Base.connection
          @connection.create_table "sections", force: true do |t|
            t.integer "position", null: false
          end
        end

        teardown do
          @connection.drop_table "sections", if_exists: true
        end

        def test_unique_constraints
          unique_constraints = @connection.unique_constraints("test_unique_constraints")

          expected_constraints = [
            {
              name: "test_unique_constraints_position_1",
              column: ["position_1"]
            }, {
              name: "test_unique_constraints_position_2",
              column: ["position_2"]
            }, {
              name: "test_unique_constraints_position_3",
              column: ["position_3"]
            }
          ]

          assert_equal expected_constraints.size, unique_constraints.size

          expected_constraints.each do |expected_constraint|
            constraint = unique_constraints.find { |constraint| constraint.name == expected_constraint[:name] }
            assert_equal "test_unique_constraints", constraint.table_name
            assert_equal expected_constraint[:name], constraint.name
            assert_equal expected_constraint[:column], constraint.column
          end
        end
      end
    end
  end
end
