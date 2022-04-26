exclude :test_add_table_with_decimals, "CockroachDB uses 64-bit signed integers, whereas the default for PG is 32-bit. The Rails test does not accommodate the 64-bit case"
exclude :test_remove_column_with_if_not_exists_not_set, "We re-implement our own version. CockroachDB does not include the table name in a 'column does not exist' message."
