exclude :test_schema_dump_with_column_infinity_default, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_schema_dump_defaults_with_universally_supported_types, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_schema_dump_with_text_column, "Re-implementing ourselves because we need CockroachDB specific methods."
