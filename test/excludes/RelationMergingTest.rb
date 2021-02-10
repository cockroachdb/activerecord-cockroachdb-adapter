exclude :test_relation_to_sql, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_merge_doesnt_duplicate_same_clauses, "We implement our own version because the sql generated is slightly different than what was in the original test."
