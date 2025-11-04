exclude :test_legacy_change_column_with_null_executes_update, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_legacy_add_foreign_key_with_deferrable_true, "CRDB does not support DEFERRABLE constraints"
exclude :test_disable_extension_on_7_0, "CRDB does not support enabling/disabling extensions."

# exclude :test_add_index_errors_on_too_long_name_7_0, "The max length in CRDB is 128, not 64."
# exclude :test_create_table_add_index_errors_on_too_long_name_7_0, "The max length in CRDB is 128, not 64."

require "support/copy_cat"

CopyCat.copy_methods(self, self,
  :test_add_index_errors_on_too_long_name_7_0,
  :test_create_table_add_index_errors_on_too_long_name_7_0
) do
  def on_sym(node)
    return unless node.children[0] == :very_long_column_name_to_test_with

    insert_after(node.loc.expression, "_and_actually_way_longer_because_cockroach_is_in_the_128_game")
  end
end

# CockroachDB does not support DDL transactions. Hence the migration is
# not rolled back and the already removed index is not restored.
#
# From:
#     if current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter)
#       assert_equal 2, foreign_keys.size
#     else
#       assert_equal 1, foreign_keys.size
#     end
# To:
#     assert_equal 1, foreign_keys.size
CopyCat.copy_methods(self, self, :test_remove_foreign_key_on_8_0) do
  def on_if(node)
    return unless node in
      [:if,
        [:send, nil, :current_adapter?,
          [:sym, :PostgreSQLAdapter],
          [:sym, :SQLite3Adapter]],
        [:send, nil, :assert_equal,
          [:int, 2],
            [:send,
              [:lvar, :foreign_keys], :size]],
        [:send, nil, :assert_equal,
          [:int, 1],
            [:send,
              [:lvar, :foreign_keys], :size]] => else_block]

    replace(node.loc.expression, else_block.location.expression.source)
  end
end
