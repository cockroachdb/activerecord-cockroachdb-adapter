comment = "This adapter quotes integers as string, as CRDB is capable of " \
  "implicitely converting, and checking for out of bound errors. " \
  "See quoting.rb for more information."
exclude :test_do_not_raise_when_int_is_not_wider_than_64bit, comment
exclude :test_do_not_raise_when_raise_int_wider_than_64bit_is_false, comment
exclude :test_raise_when_int_is_wider_than_64bit, comment
