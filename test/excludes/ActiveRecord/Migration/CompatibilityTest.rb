exclude :test_legacy_change_column_with_null_executes_update, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_legacy_add_foreign_key_with_deferrable_true, "CRDB does not support DEFERRABLE constraints"
exclude :test_disable_extension_on_7_0, "CRDB does not support enabling/disabling extensions."
# CRDB does not support ALTER COLUMN TYPE inside a transaction
BaseCompatibilityTest.descendants.each { _1.use_transactional_tests = false }

exclude :test_add_index_errors_on_too_long_name_7_0, "The max length in CRDB is 128, not 64."
exclude :test_create_table_add_index_errors_on_too_long_name_7_0, "The max length in CRDB is 128, not 64."

module ::DefaultPrecisionImplicitTestCases
  def precision_implicit_default
    { precision: 6 }
  end
end

module Ext
  def precision_implicit_default
    { precision: 6 }
  end
end

prepend Ext
