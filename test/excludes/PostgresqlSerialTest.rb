# Note: all these tests fail during setup trying to create a column with a
# sequence backed default because the sequence doesn't exist. The tests still
# fail for different reasons after the setup is fixed.
exclude :test_serial_column, "The sql_type assertion fails because integer columns are bigints in CockroachDB. See https://www.cockroachlabs.com/docs/v19.2/int.html#names-and-aliases."
exclude :test_not_serial_column, "The sql_type assertion fails because integer columns are bigints in CockroachDB. See https://www.cockroachlabs.com/docs/v19.2/int.html#names-and-aliases. The serial? assertion fails because an integer column with a serial default function is not distinguishable from a serial column. See https://www.cockroachlabs.com/docs/v19.2/serial.html#modes-of-operation."
exclude :test_schema_dump_with_shorthand, "Serial columns are backed by integer columns, and integer columns are really bigints in CockroachDB. Therefore, the dump will include bigserial instead of serial columns. See https://www.cockroachlabs.com/docs/v19.2/serial.html#generated-values-for-mode-sql_sequence."
exclude :test_schema_dump_with_not_serial, "If an integer column is created with a serial default function, it will be treated like a serial column in CockroachDB."
