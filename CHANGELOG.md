# Changelog

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
