exclude :test_exec_insert_with_returning_disabled_and_no_sequence_name_given, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_default_sequence_name, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_bad_connection, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_exec_insert_with_returning_disabled, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_only_warn_on_first_encounter_of_unrecognized_oid, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_index_with_opclass, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_exec_insert_default_values_with_returning_disabled_and_no_sequence_name_given, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_reload_type_map_for_newly_defined_types, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_unparsed_defaults_are_at_least_set_when_saving, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_default_sequence_name_bad_table, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_exec_insert_default_values_quoted_schema_with_returning_disabled_and_no_sequence_name_given, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_expression_index, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_serial_sequence, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_database_exists_returns_false_when_the_database_does_not_exist, "Test is reimplemented to use cockroachdb adapter. Still not working in CI, skip until we can triage further"
exclude :test_database_exists_returns_true_when_the_database_exists, "Test is reimplemented to use cockroachdb adapter"
exclude :test_invalid_index, "The error message differs from PostgreSQL."
exclude :test_partial_index_on_column_named_like_keyword, "CockroachDB adds parentheses around the WHERE definition."
exclude :test_only_check_for_insensitive_comparison_capability_once, "the DROP DOMAIN syntax is not supported by CRDB"

exclude :test_pk_and_sequence_for, "The test needs a little rework since the sequence is empty in CRDB"
exclude :test_pk_and_sequence_for_with_non_standard_primary_key, "The test needs a little rework since the sequence is empty in CRDB"

exclude :test_pk_and_sequence_for_with_collision_pg_class_oid, "We cannot DELETE on relation pg_depend in CockroachDB. Skipped for now"

# NOTE: The expression `do $$ BEGIN RAISE WARNING 'foo'; END; $$` works with PG, not CRDB.
plpgsql_needed = "PL-PGSQL differs in CockroachDB. Not tested yet. See #339"
exclude :test_ignores_warnings_when_behaviour_ignore, plpgsql_needed
exclude :test_logs_warnings_when_behaviour_log, plpgsql_needed
exclude :test_raises_warnings_when_behaviour_raise, plpgsql_needed
exclude :test_reports_when_behaviour_report, plpgsql_needed
exclude :test_warnings_behaviour_can_be_customized_with_a_proc, plpgsql_needed
exclude :test_allowlist_of_warnings_to_ignore, plpgsql_needed
exclude :test_allowlist_of_warning_codes_to_ignore, plpgsql_needed

exclude :test_translate_no_connection_exception_to_not_established, "CRDB doesn't implement pg_terminate_backend()"

exclude :test_disable_extension_without_schema, ExcludeMessage::NO_HSTORE
exclude :test_extensions_omits_current_schema_name, ExcludeMessage::NO_HSTORE
exclude :test_extensions_includes_non_current_schema_name, ExcludeMessage::NO_HSTORE
exclude :test_disable_extension_with_schema, ExcludeMessage::NO_HSTORE
