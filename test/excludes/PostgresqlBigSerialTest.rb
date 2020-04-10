# Note: all these tests fail during setup trying to create a column with a
# sequence backed default because the sequence doesn't exist. The tests still
# fail for different reasons after the setup is fixed.
exclude :test_bigserial_column, "The test is valid but can't pass with the bad setup."
exclude :test_not_bigserial_column, "The serial? assertion fails because a bigint column with a serial default function is not distinguishable from a serial column. See https://www.cockroachlabs.com/docs/v19.2/serial.html#modes-of-operation."
exclude :test_schema_dump_with_shorthand, "The test is valid but can't pass with the bad setup."
exclude :test_schema_dump_with_not_bigserial, "If a bigint column is created with a serial default function, it will be treated like a serial column in CockroachDB."
