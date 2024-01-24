message = 'CockroachDB does not support variable session authorization. ' \
  'See https://github.com/cockroachdb/cockroach/issues/40283'
exclude  :test_sequence_schema_caching, message
exclude  :test_session_auth=, message
exclude  :test_schema_invisible, message
exclude  :test_tables_in_current_schemas, message
exclude  :test_auth_with_bind, message
exclude  :test_setting_auth_clears_stmt_cache, message
