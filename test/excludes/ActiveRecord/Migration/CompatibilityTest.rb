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
