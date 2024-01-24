exclude :test_unique_constraints, "Removed deferrable part from constraints."

no_deferrable = "CRDB doesn't support DEFERRABLE constraints"
exclude :test_add_unique_constraint_with_deferrable_deferred, no_deferrable
exclude :test_add_unique_constraint_with_deferrable_immediate, no_deferrable
exclude :test_added_deferrable_initially_immediate_unique_constraint, no_deferrable

no_using_index = "CRDB doesn't support USING INDEX"
exclude :test_add_unique_constraint_with_name_and_using_index, no_using_index
exclude :test_add_unique_constraint_with_only_using_index, no_using_index

no_remove_unique_constraint = "CRDB doesn't support " \
  "ALTER TABLE DROP CONSTRAINT. There may be an altenative, see " \
  "https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/304"
exclude :test_remove_unique_constraint, no_remove_unique_constraint
exclude :test_remove_unique_constraint_by_column, no_remove_unique_constraint
