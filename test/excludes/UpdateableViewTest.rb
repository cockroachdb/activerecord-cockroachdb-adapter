updateable_msg = "Updateable views are not currently supported, see https://github.com/cockroachdb/cockroach/issues/20948"
exclude :test_update_record_to_fail_view_conditions, updateable_msg
exclude :test_insert_record, updateable_msg
exclude :test_insert_record_populates_primary_key, updateable_msg
exclude :test_update_record, updateable_msg
