exclude :test_legacy_change_column_with_null_executes_update, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_legacy_add_foreign_key_with_deferrable_true, "CRDB does not support DEFERRABLE constraints"
exclude :test_disable_extension_on_7_0, "CRDB does not support enabling/disabling extensions."
exclude :test_timestamps_sets_default_precision_on_create_table, "See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/307"
# CRDB does not support ALTER COLUMN TYPE inside a transaction
::DefaultPrecisionImplicitTestCases.undef_method(:test_datetime_doesnt_set_precision_on_change_column)
::DefaultPrecisionSixTestCases.undef_method(:test_datetime_sets_precision_6_on_change_column)
BaseCompatibilityTest.descendants.each { _1.use_transactional_tests = false }
