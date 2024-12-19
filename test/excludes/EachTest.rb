require "support/copy_cat"

# CockroachDB doesn't update schema information when adding an
# index until the transaction is done. Hence impossible to delete
# this index before completion of the transaction.
exclude_from_transactional_tests :test_in_batches_iterating_using_custom_columns
exclude_from_transactional_tests :test_in_batches_with_custom_columns_raises_when_non_unique_columns
exclude_from_transactional_tests :test_in_batches_when_loaded_iterates_using_custom_column
