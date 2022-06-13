exclude :test_schema_dumping, "Rewrite because the virtual column scalar expression is nil."
exclude :test_build_fixture_sql, "Skipping because CockroachDB cannot write directly to computed columns."
