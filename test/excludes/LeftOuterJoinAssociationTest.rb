exclude :test_construct_finder_sql_applies_aliases_tables_on_association_conditions, "The test fails because the query result order is not guaranteed."
exclude :test_does_not_override_select, "The select query fails because strings cannot be concated non-strings in CockroachDB."
