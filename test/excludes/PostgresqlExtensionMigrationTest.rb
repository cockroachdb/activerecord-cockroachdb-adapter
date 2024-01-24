exclude :test_disable_extension_migration_ignores_prefix_and_suffix, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_enable_extension_migration_ignores_prefix_and_suffix, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
no_hstore = "Extension \"hstore\" is not yet supported by CRDB"
exclude :test_disable_extension_drops_extension_when_cascading, no_hstore
exclude :test_disable_extension_raises_when_dependent_objects_exist, no_hstore
exclude :test_enable_extension_migration_with_schema, no_hstore
