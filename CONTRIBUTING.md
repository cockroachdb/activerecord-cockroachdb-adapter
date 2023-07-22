# Getting started


## ActiveRecord adapters and you

There are two repositories for the ActiveRecord adapter. The one you're in
currently, [activerecord-cockroachdb-adapter], is the CockroachDB specific
ActiveRecord code. Users install this alongside ActiveRecord then use
CockroachDBAdapter to initialize ActiveRecord for their projects.

This adapter extends the PostgreSQL ActiveRecord adapter in order to
override and monkey-patch functionality.

[activerecord-cockroachdb-adapter]: https://github.com/cockroachdb/activerecord-cockroachdb-adapter/

## Setup and running tests

### CockroachDB

First, You should setup a cockroachdb local instance. You can use the
`bin/start-cockroachdb` to help you with that task. Otherwise, once setup,
create two databases to be used by the ActiveRecord test suite:
activerecord_unittest and activerecord_unittest2.

```sql
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

Note that the actual CI test suit is ran with [this script](https://github.com/cockroachdb/cockroach/blob/master/pkg/cmd/roachtest/tests/activerecord.go). And test failures are tracked [cockroach#97283](https://github.com/cockroachdb/cockroach/issues/97283)

Install rbenv with ruby-build on MacOS:

```bash
brew install rbenv ruby-build
echo 'eval "$(rbenv init - zsh)"' >> ~/.profile
```

Install rbenv with ruby-build on Ubuntu:

```bash
sudo apt-get install rbenv
echo 'eval "$(rbenv init - zsh)"' >> ~/.profile

git clone https://github.com/sstephenson/ruby-build.git ~/ruby-build
sh ~/ruby-build/install.sh
```

Use rbenv to install version of Ruby specified by `.ruby-version`.

```bash
rbenv install
rbenv rehash
```

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
TEST_FILES="test/cases/adapter_test.rb" TESTOPTS=`-n=/test_indexes/` bundle exec rake test
```

`test/config.yml` assumes CockroachDB will be running at localhost:26257 with a root user. Make changes to `test/config.yml` as needed.

### Run Tests from a Backup

Loading the full test schema every time a test runs can take a while, so for cases where loading the schema sequentially is unimportant, it is possible to use a backup to set up the database. This is significantly faster than the standard method and is provided to run individual tests faster, but should not be used to validate a build.

First create the template database.

```bash
bundle exec rake db:create_test_template
```

This will create a template database for the current version (ex. `activerecord_test_template611` for version 6.1.1) and create a `BACKUP` in the `nodelocal://self/activerecord-crdb-adapter/#{activerecord_version}` directory.

To load from the template, use the `COCKROACH_LOAD_FROM_TEMPLATE` flag.

```bash
COCKROACH_LOAD_FROM_TEMPLATE=1 TEST_FILES="test/cases/adapters/postgresql/ddl_test.rb" bundle exec rake test
```

And the `activerecord_unittest` database will use the `RESTORE` command to load the schema from the template database.

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


## Execute only tests that run with a connection

I have not investigated if this is already possible, but I would assume
no.

A possible way to approach this would be to add a shim to cause any
tests that use it to fail, and grep the tests that pass and then skip
them.

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


## Tracked test failures

Some of the skipped failures are:

- `default:` key is not working for columns in table schema
  definitions. This causes tests to fail due to unexpected data.

- `array:` key is not working for columns in table schema definitions.

- `"Salary is not appearing in list"` is being raised in a number of
  places. Likely during fixture setup.

- `sum` function seems to result in a different type in ActiveRecord.
  Instead of returning a Ruby `int`, it returns a Ruby `string`. It
  appears that MySQL2 also does this. A suspected cause might be how
  `Decimal` is handled if `sum` consumes integers and return a
  decimal.

- Potentially fork the PostgreSQL::SchemaDumper to handle anything
  specific to CockroachDB, like primary keys or bigints.

- You can call `@connection.create_table(..., id: :bigint)`, but this
  will not changes things for CockroachDB (I think...), so it would be
  not allowed. Even better, our adapter could interpret this and
  generate the appropriate explicit pkey column. Not sure what string
  pkeys look like...

- `string` types are introspected to `text` types.

- A user can do an update, delete, and insert on views.

- Postgres specific bit strings are not properly supported.

Grepping for `FIXME(joey)`, `TODO(joey)`, and `NOTE(joey)` will yeild
most of the touchpoints including test failures and temporary monkey
patches. Some monkey patches were made directly to Rails, which will
need to be cleaned up.


# Notes for the non-Rubyer

rbenv is an environment manager that lets you manage and swap between
multiple versions of Ruby and their dependencies.

bundle is dependency manager that uses a projects `Gemfile` (and often
`<project>.gemspec`) to manage and load dependencies and their required
versions. When using projects commands are prefixed with
`bundle exec ...`. Bundle will ensure that all dependencies are fetched
and used.
