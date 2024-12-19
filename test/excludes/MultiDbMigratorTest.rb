# We can't add and remove a column in the same transaction with CockroachDB
exclude_from_transactional_tests :test_internal_metadata_stores_environment
