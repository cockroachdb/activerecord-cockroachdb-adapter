exclude :test_disable_extension_migration_ignores_prefix_and_suffix, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_enable_extension_migration_ignores_prefix_and_suffix, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_disable_extension_drops_extension_when_cascading, ExcludeMessage::NO_HSTORE
exclude :test_disable_extension_raises_when_dependent_objects_exist, ExcludeMessage::NO_HSTORE
exclude :test_enable_extension_migration_with_schema, ExcludeMessage::NO_HSTORE
