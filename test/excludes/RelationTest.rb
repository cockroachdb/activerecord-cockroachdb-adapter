exclude :test_finding_with_sanitized_order, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_finding_with_subquery_with_eager_loading_in_from, "Overridden because test depends on ordering of results."
exclude :test_finding_with_arel_sql_order, "Result is quoted in CockroachDB."
