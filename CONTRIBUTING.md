# Getting started


## ActiveRecord adapters and you

There are two repositories for the ActiveRecord adapter. The one you're in
currently, [activerecord-cockroachdb-adapter], is the CockroachDB specific
ActiveRecord code. Users install this alongside ActiveRecord then use
CockroachDBAdapter to initialize ActiveRecord for their projects.

This adapter extends the PostgreSQL ActiveRecord adapter in order to
override and monkey-patch functionality.

The other repository is a fork of [Rails]. The tests have been modified
for the purposes of testing our CockroachDB adapter.

[activerecord-cockroachdb-adapter]: https://github.com/cockroachdb/activerecord-cockroachdb-adapter/
[Rails]: https://github.com/lego/ruby-on-rails


## Setup and running tests

It is best to have a Ruby environment manager installed, such as
[rvm](https://rvm.io/), as Rails has varying Ruby version requirements.
If you are using rvm, you then install and use the required Ruby
version.  The current tests use Rails 5.2.0 beta and Ruby >= 2.2.2.

(Alternatively, one can use `./docker.sh build/teamcity-test.sh` to run
tests similarily to TeamCity. The database is destroyed between each
test file.)


```bash
rvm install 2.2.5
# This only makes Ruby 2.2.5 active for the length of the terminal session.
rvm use 2.2.5
```

Using [bundler](http://bundler.io/), install the dependancies of Rails.
Additionally, make sure the Rails git submodule is loaded.

```bash
# Ensure the rails fork is fetched.
git submodule update
# Install rails dependancies.
(cd rails && bundle install)
```

Then, to run the test with an active CockroachDB instance:

```bash
cp build/config.teamcity.yml rails/activerecord/test/config.yml
(cd rails/activerecord && BUNDLE_GEMFILE=../Gemfile bundle exec rake db:cockroachdb:rebuild)
(cd rails/activerecord && BUNDLE_GEMFILE=../Gemfile bundle exec rake test:cockroachdb)
```

### Test commands in detail

```bash
cp build/config.teamcity.yml rails/activerecord/test/config.yml
```

This copies the TeamCity ActiveRecord configuration for the application.
This configuration specifies:

- CockroachDB port and host the test suite uses.
- Database names used for the different test connections. (ActiveRecord
  uses two separate connections for some tests.)

```
(cd rails/activerecord && BUNDLE_GEMFILE=../Gemfile bundle exec rake db:cockroachdb:rebuild)
```

This prepares CockroachDB for running tests. It only drops and
re-creates all of the databases needed.

- This command needs to be run from activerecord folder in order to use
  the ActiveRecord `Rakefile`. The `Rakefile` defines scripts (called
  tasks) such as executing tests.
- `BUNDLE_GEMFILE=../Gemfile` tells `bundle` to use the dependancies for
  Rails that were previously installed.
- `bundle exec rake` uses `bundle` to execute the Ruby package `rake`.
- `rake db:cockroachdb:rebuild` runs the specified Rake task. All tasks
  can be found in `rails/activerecord/Rakefile`.


```
(cd rails/activerecord && BUNDLE_GEMFILE=../Gemfile bundle exec rake test:cockroachdb)
```

This executes the CockroachDB tests.

- Like the previous command, this one uses the Activerecord Rakefile and
  the Rails Gemfile. The task code can be found in the Rakefile.
- Running specific test files can be done by appending
  `TESTFILES=test/cases/attribute_methods.rb` to the command. Globs are
  used. Multiple individual files cannot be specified.


# Improvements


## Support past Rails versions

Currently, only a beta version of Rails is tested. This means that the
adapter has been modified in to accomodate unreleased changes. In order
to run the tests for Rails 5.1 or 4.2, the test changes will need to be
cherry-picked back. Conflicts are mostly only expected for tests that
have not yet been added.

Sadly, this does mean that we will have to have multiple versions of the
driver for the multiple versions of Rails.

A proposal for the CockroachDB adapter versioning would be to follow
ActiveRecord minor versions. For example, if you use Rails 4.2.5, you
would specify the CockroachDB version `~> 4.2.0`.


## Running CI automatically

Currently the fork is set up to run using TeamCity only on the current
master branch, with an alpha build of CockroachDB. it would be even
better to be able to test multiple versions of the adapter, and do so
against different versions of CockroachDB.


## Adding feature support

As CockroachDB improves, so do the features that can be supported in
ActiveRecord. Many of them are gated by conditions the
CockroachDBAdapter has overrided. As these features are completed, these
gates should be toggled. Something that would help this process would be
linking those issues back to this adapter so that part of the feature
completing includes updating the adapter.


## Execute only tests that run with a connection

I have not investigated if this is already possible, but I would assume
no.

A possible way to approach this would be to add a shim to cause any
tests that use it to fail, and grep the tests that pass and then skip
them.

# Cleanup

One of the earlier commits to the Rails repo did a big grep of
`PostgreSQLAdapter` -> `CockroachDBAdapter`. In order to better support
changes upstream, this modification should be changed to instead only
add `CockroachDBAdapter` alongside any `PostgreSQLAdapter`. The later
test cleanup commit will conflict on any further changes (like adding
back PostgreSQL, or removing CockroachDB for PostgreSQL).

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

rvm is an environment manager that lets you manage and swap between
multiple verisons of Ruby and their dependancies.

bundle is dependancy manager that uses a projects `Gemfile` (and often
`<project>.gemspec`) to manage and load dependancies and their required
versions. When using projects commands are prefixed with
`bundle exec ...`. Bundle will ensure that all depenedncies are fetched
and used.
