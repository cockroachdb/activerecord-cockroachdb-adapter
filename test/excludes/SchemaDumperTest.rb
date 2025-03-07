exclude :test_schema_dump_allows_array_of_decimal_defaults, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_foreign_keys_are_dumped_at_the_bottom_to_circumvent_dependency_issues, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_schema_dump_interval_type, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_do_not_dump_foreign_keys_for_ignored_tables, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_schema_dump_includes_bigint_default, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_schema_dump_with_timestamptz_datetime_format, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_schema_dump_with_correct_timestamp_types_via_add_column_with_type_as_string, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_timestamps_schema_dump_before_rails_7_with_timestamptz_setting, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_schema_dump_with_correct_timestamp_types_via_add_column_before_rails_7_with_timestamptz_setting, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_schema_dump_when_changing_datetime_type_for_an_existing_app, "Re-implementing ourselves because we need CockroachDB specific methods."
exclude :test_schema_dumps_check_constraints, "Re-implementing because some constraints are now written in parenthesis"
