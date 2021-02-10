exclude :test_uniqueness_validation_ignores_uuid, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_change_column_default, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_uuid_formats, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_uuid_change_case_does_not_mark_dirty, "This test is re-implemented by us. The original version tests with an invalid UUID, which causes CockroachDB to raise an exception."
