no_deferrable = "CRDB does not support DEFERRABLE constraints"
exclude "test_deferrable:_:immediate_option_can_be_passed", no_deferrable
exclude "test_deferrable:_:deferred_option_can_be_passed", no_deferrable
exclude "test_deferrable_and_on_(delete|update)_option_can_be_passed", no_deferrable
