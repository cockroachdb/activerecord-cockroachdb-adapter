# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_check_constraints?
  module ActiveRecord
    module CockroachDB
      class Migration
        class CheckConstraintTest < ActiveRecord::TestCase
          include SchemaDumpingHelper
          self.use_transactional_tests = false

          class Trade < ActiveRecord::Base
          end

          setup do
            @connection = ActiveRecord::Base.connection
            @connection.create_table "trades", force: true do |t|
              t.integer :price
              t.integer :quantity
            end
          end

          teardown do
            @connection.drop_table "trades", if_exists: true rescue nil
          end

          if ActiveRecord::Base.connection.supports_validate_constraints?
            # keep
            def test_validate_check_constraint_by_name
              @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false
              assert_not_predicate @connection.check_constraints("trades").first, :validated?

              @connection.validate_check_constraint :trades, name: "quantity_check"
              assert_predicate @connection.check_constraints("trades").first, :validated?
            end
          end

          # keep
          def test_remove_check_constraint
            @connection.add_check_constraint :trades, "price > 0", name: "price_check"
            @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check"

            assert_equal 2, @connection.check_constraints("trades").size
            @connection.remove_check_constraint :trades, name: "quantity_check"
            assert_equal 1, @connection.check_constraints("trades").size

            constraint = @connection.check_constraints("trades").first
            assert_equal "trades", constraint.table_name
            assert_equal "price_check", constraint.name

            if current_adapter?(:Mysql2Adapter)
              assert_equal "`price` > 0", constraint.expression
            else
              assert_equal "price > 0", constraint.expression
            end
          end
        end
      end
    end
  end
end
