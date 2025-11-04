exclude :test_should_reraise_invalid_foreign_key_exception_and_show_warning,
    "CockroachDB has a different limitation as there is no" \
    "'DISABLE TRIGGER' statement."

break_tx = "CockroachDB will always alter transactions when " \
  "trying to disable referential integrity. Either it cannot " \
  "work within transaction, or autocommit_before_ddl is set " \
  "and transactions will be committed."
exclude :test_does_not_break_transactions, break_tx
exclude :test_does_not_break_nested_transactions, break_tx

exclude :test_only_catch_active_record_errors_others_bubble_up,
    "Reimplemented in test/cases/adapters/cockroachdb/referential_integrity_test.rb" \
    " to use a different trigger for the error."
