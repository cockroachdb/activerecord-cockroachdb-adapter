# `test_cache_gets_cleared_after_migration` runs `change_column :posts, :title,
# :string, limit: 80`, which adds a length limit to a VARCHAR column. Since
# cockroachdb/cockroach@5a8fd7226192 (v26.2), converting an unbounded string to a
# bounded one validates existing data, and CockroachDB does not allow such a
# conversion inside an explicit transaction (see
# https://go.crdb.dev/issue-v/49351/v26.2). Running the test non-transactionally
# lets change_column execute as an implicit single-statement transaction, which
# is allowed. Earlier versions treat the change as metadata-only and are
# unaffected, so this is safe across all supported versions.
exclude_from_transactional_tests :test_cache_gets_cleared_after_migration
