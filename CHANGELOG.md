# Changelog

## 6.0.3 - 2021-08-13

- Santitize the input to the telemetry query that is issued on startup.
- Add support for CockroachDB v21.

## 6.0.2 - 2021-05-20

- Fix a bug where starting the driver can result in a ConnectionNotEstablished error.

## 6.0.1 - 2021-05-14

- Fix a bug where starting the driver can result in a NoDatabaseError.

## 6.0.0 - 2021-04-26

- Add a telemetry query on start-up. This helps the Cockroach Labs team
  prioritize support for the adapter. It can be disabled by setting the
  `disable_cockroachdb_telemetry` configuration option to false.

## 6.0.0-beta.5 - 2021-04-02

- Added a configuration option named `use_follower_reads_for_type_introspection`.
  If true, it improves the speed of type introspection by allowing potentially stale
  type metadata to be read. Defaults to false.

## 6.0.0-beta.4 - 2021-03-06

- Improved connection performance by refactoring an introspection
  that loads types.
- Changed version numbers to semver.

## 6.0.0beta3

- Added support for spatial features.

## 6.0.0beta2

- Updated transaction retry logic to work with Rails 6.

## 6.0.0beta1

- Initial support for Rails 6.
