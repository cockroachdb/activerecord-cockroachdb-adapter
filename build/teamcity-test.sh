#!/usr/bin/env bash

set -euo pipefail

# Download CockroachDB. NB: currently this uses an alpha, due to feature
# requirements.
VERSION=v2.0-alpha.20171218
wget -qO- https://binaries.cockroachdb.com/cockroach-$VERSION.linux-amd64.tgz | tar  xvz
readonly COCKROACH=./cockroach-$VERSION.linux-amd64/cockroach

# Make sure cockroach can be found on the path. This is required for the
# ActiveRecord Rakefile that rebuilds the test database.
export PATH=$(pwd)/cockroach-$VERSION.linux-amd64/:$PATH
readonly urlfile=cockroach-url

run_cockroach() {
  # Start a CockroachDB server, wait for it to become ready, and arrange
  # for it to be force-killed when the script exits.
  rm -f "$urlfile"
  # Clean out a past CockroachDB instance. This will clean out leftovers
  # from the build agent, and also between CockroachDB runs.
  cockroach quit --insecure || true
  rm -rf cockroach-data
  # Start CockroachDB.
  cockroach start --insecure --host=localhost --listening-url-file="$urlfile" &
  # Ensure CockroachDB is stopped on script exit.
  trap "echo 'Exit routine: Killing CockroachDB.' && kill -9 $! &> /dev/null" EXIT
  # Wait until CockroachDB has started.
  for i in {0..3}; do
    [[ -f "$urlfile" ]] && break
    backoff=$((2 ** i))
    echo "server not yet available; sleeping for $backoff seconds"
    sleep $backoff
  done
}

# Target the Rails dependency file.
export BUNDLE_GEMFILE=$(pwd)/rails/Gemfile

# Install ruby dependencies.
bundle install

cp build/config.teamcity.yml rails/activerecord/test/config.yml

# 'Install' our adapter. This involves symlinking it inside of
# ActiveRecord. Normally the adapter will transitively install
# ActiveRecord, but we need to execute tests from inside the Rails
# context so we cannot rely on that. We also need previous links to make
# tests idempotent.
rm -f rails/activerecord/lib/active_record/connection_adapters/cockroachdb_adapter.rb
ln -s $(pwd)/lib/active_record/connection_adapters/cockroachdb_adapter.rb rails/activerecord/lib/active_record/connection_adapters/cockroachdb_adapter.rb
rm -rf rails/activerecord/lib/active_record/connection_adapters/cockroachdb
ln -s $(pwd)/lib/active_record/connection_adapters/cockroachdb rails/activerecord/lib/active_record/connection_adapters/cockroachdb

# Get the test files with "# FILE(OK)". These should pass.
TESTS=$(find rails/activerecord/test/cases -type f \( -name "*_test.rb" \) -exec grep -l "# FILE(OK)" {} +)

while read -r TESTFILE; do
  # Start CockroachDB
  run_cockroach
  # Run the tests.
  echo "Rebuilding database"
  (cd rails/activerecord && bundle exec rake db:cockroachdb:rebuild)
  echo "Starting test for $TESTFILE"
  # Run the test. Continue testing even if this file fails.
  PREFIX=rails/activerecord
  TESTFILE=${TESTFILE#$PREFIX}
  (cd rails/activerecord && bundle exec rake test:cockroachdb TESTFILES=$TESTFILE) || true
done <<< $TESTS

# Attempt a clean shutdown for good measure. We'll force-kill in the
# exit trap if this script fails.
cockroach quit --insecure
trap - EXIT
