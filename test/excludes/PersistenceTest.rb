exclude :test_reset_column_information_resets_children, "This test fails because the column is created in the same transaction in which the test attempts to assert/operate further."
exclude :test_fills_auto_populated_columns_on_creation, "See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/308"
