# Changelog

## 7.0.0 - 2021-12-17

- Add support for ActiveRecord 7.0.

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
