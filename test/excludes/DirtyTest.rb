exclude :test_field_named_field, "Rails transactional tests are being used while making schema changes. See https://www.cockroachlabs.com/docs/stable/online-schema-changes.html#limited-support-for-schema-changes-within-transactions."
exclude :test_partial_update_with_optimistic_locking, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_virtual_attributes_are_not_written_with_partial_writes_off, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
