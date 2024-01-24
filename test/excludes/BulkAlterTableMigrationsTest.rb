exclude :test_changing_columns, "Type conversion from DATE to TIMESTAMP requires overwriting existing values which is not yet implemented. https://github.com/cockroachdb/cockroach/issues/9851"
exclude :test_changing_column_null_with_default, "Type conversion from DATE to TIMESTAMP requires overwriting existing values which is not yet implemented. https://github.com/cockroachdb/cockroach/issues/9851"

exclude :test_adding_indexes, "Need to reference the specific query count for CockroachDB"
exclude :test_removing_index, "Need to reference the specific query count for CockroachDB"
exclude :test_adding_multiple_columns, "Need to reference the specific query count for CockroachDB"
exclude :test_changing_index, "Need to reference the specific query count for CockroachDB"
