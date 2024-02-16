# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "support/copy_cat"

module ActiveRecord
  module CockroachDB
    class Migration
      class CompatibilityTest < ActiveRecord::Migration::CompatibilityTest
        CopyCat.copy_methods(self, ActiveRecord::Migration::CompatibilityTest,
          :test_add_index_errors_on_too_long_name_7_0,
          :test_create_table_add_index_errors_on_too_long_name_7_0
        ) do
          def on_sym(node)
            return unless node.children[0] == :very_long_column_name_to_test_with

            insert_after(node.loc.expression, "_and_actually_way_longer_because_cockroach_is_in_the_128_game")
          end
        end
      end
    end
  end
end
