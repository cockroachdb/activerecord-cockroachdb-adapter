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
exclude :test_database_exists_returns_false_when_the_database_does_not_exist, "Test is reimplemented to use cockroachdb adapter"
exclude :test_database_exists_returns_true_when_the_database_exists, "Test is reimplemented to use cockroachdb adapter"
exclude :test_invalid_index, "The error message differs from PostgreSQL."
exclude :test_partial_index_on_column_named_like_keyword, "CockroachDB adds parentheses around the WHERE definition."
exclude :test_only_check_for_insensitive_comparison_capability_once, "the DROP DOMAIN syntax is not supported by CRDB"


plpgsql_needed = "Will be testable with CRDB 23.2, introducing PL-PGSQL"
exclude :test_ignores_warnings_when_behaviour_ignore, plpgsql_needed
exclude :test_logs_warnings_when_behaviour_log, plpgsql_needed
exclude :test_raises_warnings_when_behaviour_raise, plpgsql_needed
exclude :test_reports_when_behaviour_report, plpgsql_needed
exclude :test_warnings_behaviour_can_be_customized_with_a_proc, plpgsql_needed
exclude :test_allowlist_of_warnings_to_ignore, plpgsql_needed
exclude :test_allowlist_of_warning_codes_to_ignore, plpgsql_needed
