# frozen_string_literal: true


# Materialized views in CRDB do not show up in `pg_class` in
# the transaction they are created. Try this again to see if
# it changed:
#
# ```sql
# BEGIN;
# CREATE MATERIALIZED VIEW foo AS SELECT 1;
# SELECT * FROM pg_class WHERE relname = 'foo';
# ```
self.use_transactional_tests = false
