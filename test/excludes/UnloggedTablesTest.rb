exclude :test_unlogged_in_test_environment_when_unlogged_setting_enabled, "Override because UNLOGGED cannot be specified in CockroachDB. Related https://github.com/cockroachdb/cockroach/issues/56827"
exclude :test_gracefully_handles_temporary_tables, "This override can be removed after it be fix. Related https://github.com/cockroachdb/cockroach/issues/56656"
