# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_check_constraints?
  module ActiveRecord
    module CockroachDB
      class Migration
        class CheckConstraintTest < ActiveRecord::TestCase
          include SchemaDumpingHelper
          self.use_transactional_tests = false

          class Trade < ActiveRecord::Base
          end

          setup do
            @connection = ActiveRecord::Base.lease_connection
            @connection.create_table "trades", force: true do |t|
              t.integer :price
              t.integer :quantity
            end
          end

          teardown do
            @connection.drop_table "trades", if_exists: true
          end

          if ActiveRecord::Base.lease_connection.supports_validate_constraints?
            # keep
            def test_validate_check_constraint_by_name
              @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false
              assert_not_predicate @connection.check_constraints("trades").first, :validated?

              @connection.validate_check_constraint :trades, name: "quantity_check"
              assert_predicate @connection.check_constraints("trades").first, :validated?
            end
          end

          # ExcludeMessage::VALIDATE_BUG
          # def test_schema_dumping_with_validate_false
          #   @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: false

          #   output = dump_table_schema "trades"

          #   assert_match %r{\s+t.check_constraint "(quantity > 0)", name: "quantity_check", validate: false$}, output
          # end

          def test_schema_dumping_with_validate_true
            @connection.add_check_constraint :trades, "quantity > 0", name: "quantity_check", validate: true

            output = dump_table_schema "trades"

            assert_match %r{\s+t.check_constraint "\(quantity > 0\)", name: "quantity_check"$}, output
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
              assert_equal "(price > 0)", constraint.expression
            end
          end

          def test_check_constraints
            check_constraints = @connection.check_constraints("products")
            assert_equal 1, check_constraints.size

            constraint = check_constraints.first
            assert_equal "products", constraint.table_name
            assert_equal "products_price_check", constraint.name

            if current_adapter?(:Mysql2Adapter)
              assert_equal "`price` > `discounted_price`", constraint.expression
            else
              assert_equal "(price > discounted_price)", constraint.expression
            end

            if current_adapter?(:PostgreSQLAdapter)
              begin
                # Test that complex expression is correctly parsed from the database
                @connection.add_check_constraint(:trades,
                  "CASE WHEN price IS NOT NULL THEN true ELSE false END", name: "price_is_required")

                constraint = @connection.check_constraints("trades").find { |c| c.name == "price_is_required" }
                assert_includes constraint.expression, "WHEN price IS NOT NULL"
              ensure
                @connection.remove_check_constraint(:trades, name: "price_is_required")
              end
            end
          end

          def test_add_check_constraint
            @connection.add_check_constraint :trades, "quantity > 0"

            check_constraints = @connection.check_constraints("trades")
            assert_equal 1, check_constraints.size

            constraint = check_constraints.first
            assert_equal "trades", constraint.table_name
            assert_equal "chk_rails_2189e9f96c", constraint.name

            if current_adapter?(:Mysql2Adapter)
              assert_equal "`quantity` > 0", constraint.expression
            else
              assert_equal "(quantity > 0)", constraint.expression
            end
          end
        end
      end
    end
  end
end
