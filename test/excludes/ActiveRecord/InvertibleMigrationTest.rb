exclude :test_migrate_enable_and_disable_extension, "CockroachDB doesn't support enabling/disabling extensions."
exclude :test_migrate_revert_change_column_default, "The test fails because type information is stripped from string column default values when the default is changed in the database. Possibly caused by https://github.com/cockroachdb/cockroach/issues/47285."
