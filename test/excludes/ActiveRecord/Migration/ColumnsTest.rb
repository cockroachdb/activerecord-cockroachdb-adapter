exclude :test_change_column, "This operation is not currently supported in CockroachDB, see cockroachdb/cockroach#9851"
exclude :test_change_column_default, "This test fails because type information is stripped from string column default values when the default is changed in the database. Possibly caused by https://github.com/cockroachdb/cockroach/issues/47285."
exclude :test_change_column_default_with_from_and_to, "This test fails because type information is stripped from string column default values when the default is changed in the database. Possibly caused by https://github.com/cockroachdb/cockroach/issues/47285."
exclude :test_remove_column_with_multi_column_index, "This test fails because it lacks the requisite CASCADE clause to fully remove the column"
