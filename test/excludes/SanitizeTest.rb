exclude :test_bind_enumerable, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_named_bind_variables, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_sanitize_sql_array_handles_named_bind_variables, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_bind_range, "This test is overridden for CockroachDB because this adapter adds quotes to numeric values."
