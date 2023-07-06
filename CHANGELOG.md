# Changelog

## Ongoing

- Add support for sql dump in rake tasks (#273).
- Add support for table optimize hints (#266).

## 7.0.2 - 2023-05-23

- Fix default numbers test to expect the correct result after
  https://github.com/cockroachdb/cockroach/pull/102299 was merged.

## 7.0.1 - 2023-03-24

- Reconnect on retryable connection errors.

## 7.0.0 - 2022-06-02

- Add support for Active Record 7.0.3

## 6.1.10 - 2022-05-06

- Disable supports_expression_index regardless of CockroachDB version until
  `ON CONFLICT expression` is supported.

  See https://github.com/cockroachdb/cockroach/issues/67893.

## 6.1.9 - 2022-04-26

- Fix bug where duplicate `rowid` columns would be created when loading
  a schema dump of a table that was not created with an explicit primary key.
- Support the NOT VISIBLE syntax from CockroachDB, by using the `hidden`
  column modifier in the Rails schema.

## 6.1.8 - 2022-03-14

- Add a test helper from https://github.com/rails/rails/pull/40822
  to be able to test against Rails upstream.

## 6.1.7 - 2022-03-01

- Fix query to get the CockroachDB version so it does not require any privileges.

## 6.1.6 - 2022-02-25

- Fix mixed versions of CockroachDB v21.1 and v21.2 not working.

## 6.1.5 - 2022-02-08

- Support `atttypmod` being sent for DECIMAL types.
  This is needed for CockroachDB v22.1.

## 6.1.4 - 2021-12-09

- Add support for CockroachDB v21.2.

## 6.1.3 - 2021-07-28

- Santitize the input to the telemetry query that is issued on startup.

## 6.1.2 - 2021-05-20

- Fix a bug where starting the driver can result in a ConnectionNotEstablished error.

## 6.1.1 - 2021-05-14

- Fix a bug where starting the driver can result in a NoDatabaseError.

## 6.1.0 - 2021-04-26

- Add a telemetry query on start-up. This helps the Cockroach Labs team
  prioritize support for the adapter. It can be disabled by setting the
  `disable_cockroachdb_telemetry` configuration option to false.

## 6.1.0-beta.3 - 2021-04-02

- Added a configuration option named `use_follower_reads_for_type_introspection`.
  If true, it improves the speed of type introspection by allowing potentially stale
  type metadata to be read. Defaults to false.

## 6.1.0-beta.2 - 2021-03-06

- Improved connection performance by refactoring an introspection
  that loads types.
- Changed version numbers to semver.

## 6.1.0beta1

- Initial support for Rails 6.1.
- Support for spatial functionality.
