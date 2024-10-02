transactional_test_msg = "Rails transactional tests are being used while making schema changes. " \
  "See https://www.cockroachlabs.com/docs/stable/online-schema-changes.html#limited-support-for-schema-changes-within-transactions."
exclude :test_indexes, transactional_test_msg
exclude :test_remove_index_when_name_and_wrong_column_name_specified, transactional_test_msg
exclude :test_remove_index_when_name_and_wrong_column_name_specified_positional_argument, transactional_test_msg
