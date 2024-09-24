
ago_msg = "'ago' is not supported in CRDB's interval parsing. Test ignored. See #340"
exclude :test_text_columns_are_limitless_the_upper_limit_is_one_GB, ago_msg
exclude :test_data_type_of_oid_types, ago_msg
exclude :test_update_oid, ago_msg
exclude :test_data_type_of_time_types, ago_msg
exclude :test_oid_values, ago_msg
exclude :test_time_values, ago_msg
exclude :test_update_large_time_in_seconds, ago_msg
