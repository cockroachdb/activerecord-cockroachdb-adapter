# Getting started

## Setup and running tests

### CockroachDB

First, You should setup a cockroachdb local instance. You can use the
`bin/start-cockroachdb` to help you with that task. Otherwise, once setup,
create two databases to be used by the ActiveRecord test suite:
activerecord_unittest and activerecord_unittest2.

```sql
-- See /setup.sql file for the whole setup.
CREATE DATABASE activerecord_unittest;
CREATE DATABASE activerecord_unittest2;
```

It is best to have a Ruby environment manager installed, such as
[rbenv](https://github.com/rbenv/rbenv), as Rails has varying Ruby version
requirements. If you are using rbenv, you then install and use the required
Ruby version.

(Alternatively, one can use `./docker.sh build/teamcity-test.sh` to run
tests similarly to TeamCity. The database is destroyed between each
test file.)

Using [bundler](http://bundler.io/), install the dependencies of Rails.

```bash
bundle install
```

Then, to run the full test suite with an active CockroachDB instance:

```bash
bundle exec rake test
```

To run specific ActiveRecord tests, set environment variable `TEST_FILES_AR`. For example, to run ActiveRecord tests `test/cases/associations_test.rb` and `test/cases/ar_schema_test.rb.rb`

```bash
TEST_FILES_AR="test/cases/associations_test.rb,test/cases/ar_schema_test.rb" bundle exec rake test
```

To run specific CockroachDB Adapter tests, set environment variable `TEST_FILES`. For example, to run CockroachDB Adpater tests `test/cases/adapter_test.rb` and `test/cases/associations/left_outer_join_association_test.rb`

```bash
TEST_FILES="test/cases/adapter_test.rb,test/cases/associations/left_outer_join_association_test.rb" bundle exec rake test
```

To run a specific test case, use minitest's `-n` option to run tests that match a given pattern. All minitest options are set via the `TESTOPTS` environemnt variable. For example, to run `test_indexes` from CockroachDB's `test/cases/adapter_test.rb` file

```bash
TEST_FILES="test/cases/adapter_test.rb" TESTOPTS=`--name=/test_indexes/` bundle exec rake test
```

You can also use the constant `COCKROACH_SKIP_LOAD_SCHEMA` to avoid reloading the schema every time (faster).
Only do it if you know the schema was left in a correct state.

`test/config.yml` assumes CockroachDB will be running at localhost:26257 with a root user. Make changes to `test/config.yml` as needed.

### Run Tests from a Backup

Loading the full test schema every time a test runs can take
a while, so for cases where loading the schema sequentially
is unimportant, it is possible to use a backup to set up the
database. This is significantly faster than the standard
method and is provided to run individual tests faster, but
should not be used to validate a build.

To do so, just set the env variable `COCKROACH_LOAD_FROM_TEMPLATE`.
First run will generate and cache a template, latter runs will use
it.

# Improvements

## Running CI automatically

Currently the fork is set up to run using TeamCity only on the current
master branch, with an alpha build of CockroachDB. it would be even
better to be able to test multiple versions of the adapter, and do so
against different versions of CockroachDB.

## Adding feature support

As CockroachDB improves, so do the features that can be supported in
ActiveRecord. Many of them are gated by conditions the
CockroachDBAdapter has overridden. As these features are completed, these
gates should be toggled. Something that would help this process would be
linking those issues back to this adapter so that part of the feature
completing includes updating the adapter.

## Upgrading Rails

Whenever you upgrade rails version, loads of things will change.
This section intent to help you with a checklist.

- Check for TODO or NOTE tags that are referencing the old or new version of
  rails.
  ```bash
  rg 'TODO|NOTE' --after-context=2
  ```
- Check postgresql_specific_schema.rb changelog in rails, and apply the changes
  you want. Ex:
  ```bash
  git diff v7.1.4..v7.2.1 -- $(fd postgresql_specific_schema)
  ```
- Verify the written text at the beginning of the test suite, there are likely
  some changes in excluded tests.
- Check for some important methods, some will change for sure:
  - [ ] `def new_column_from_field(`
  - [ ] `def column_definitions(`
  - [ ] `def pk_and_sequence_for(`
  - [ ] `def foreign_keys(` and `def all_foreign_keys(`
  - [ ] ...
- Check for setups containing `drop_table` in the test suite.
  Especially if you have tons of failure, this is likely the cause.
- In the same way, run `test/cases/fixtures_test.rb` first, and check
  if this corrupted the test database for other tests.
- For both of the above, the diff of `schema.rb` can be useful:
  ```bash
  git diff v7.1.2..v7.2.1 -- activerecord/test/schema/schema.rb
  ```

## Publishing to Rubygems

TODO: Expand on this. Jordan is likely the only person with publishing
credentials. I'm not sure if there is anything else other than:

```
gem build ...
gem publish <output file>
```

# Notes

When executing the test suite, each test file will reload fixtures. This
drops and creates about 200 tables (2 databases, 100 tables each).
Currently there are performance problems that rise from having lots of
table descriptors around, [cockroachdb/cockroach#20753]. At best, we can
run test files individually, clear out the CockroachDB data, and restart
the node to alleviate this.

Currently, annotations have been added to test files to indicate if it
is failing, and some brief details on why. Any annotated failures have
been skipped right now for further investigation. The pattern is the
following:

`# FILE(OK)` indicates that the file is currently passing, with no skips
required.

`# FILE(BAD)` indicates that there are failures that have been skipped.
These skips will look like `skip(reason) if current_adapter?(:CockroachDBAdapter)`.

`# FILE(BROKEN)` indicates that there are failures that have not been
skipped. This is often done if the entirety of a test file is
unsupported.

`# FILE(NOT DONE)` indicates files that have not yet been executed,
cleaned up, or skipped until passing.

The purpose of these was to make the tests grep-able while going through
all the failures.

[cockroachdb/cockroach#20753]: https://github.com/cockroachdb/cockroach/issues/20753#issuecomment-352810425

# Notes for the non-Rubyer

rbenv is an environment manager that lets you manage and swap between
multiple versions of Ruby and their dependencies.

bundle is dependency manager that uses a projects `Gemfile` (and often
`<project>.gemspec`) to manage and load dependencies and their required
versions. When using projects commands are prefixed with
`bundle exec ...`. Bundle will ensure that all dependencies are fetched
and used.
