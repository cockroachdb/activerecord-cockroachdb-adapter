exclude :test_validate_uniqueness_uuid, "This test is only meant to be run with a PostgreSQL adapter"
exclude :test_validate_case_insensitive_uniqueness, "This tests relies on an implemented pg_cast table, see cockroach/cockroach#47498 for more details"
