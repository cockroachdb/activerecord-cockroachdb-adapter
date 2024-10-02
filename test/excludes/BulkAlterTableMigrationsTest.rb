exclude :test_changing_columns, "Type conversion from DATE to TIMESTAMP requires overwriting existing values which is not yet implemented. https://github.com/cockroachdb/cockroach/issues/9851"
exclude :test_changing_column_null_with_default, "Type conversion from DATE to TIMESTAMP requires overwriting existing values which is not yet implemented. https://github.com/cockroachdb/cockroach/issues/9851"

query_count_msg = "Need to reference the specific query count for CockroachDB. Fixed in test/cases/migration_test.rb"
exclude :test_adding_indexes, query_count_msg
exclude :test_removing_index, query_count_msg
exclude :test_adding_multiple_columns, query_count_msg
exclude :test_changing_index, query_count_msg
