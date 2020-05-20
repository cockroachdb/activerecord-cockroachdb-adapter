exclude :test_adding_indexes, "See test/cases/migration_test.rb for CockroachDB-specific test case"
exclude :test_changing_columns, "Type conversion from DATE to TIMESTAMP requires overwriting existing values which is not yet implemented. https://github.com/cockroachdb/cockroach/issues/9851"
exclude :test_adding_multiple_columns, "See test/cases/migration_test.rb for CockroachDB-specific test case"
