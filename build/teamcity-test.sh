#!/usr/bin/env bash

set -euox pipefail

# Download CockroachDB
VERSION=v20.1.0-rc.1
#wget -qO- https://binaries.cockroachdb.com/cockroach-$VERSION.linux-amd64.tgz | tar  xvz
#readonly COCKROACH=./cockroach-$VERSION.linux-amd64/cockroach

mkdir -p ./cockroach
wget -q -O cockroach/cockroach https://edge-binaries.cockroachdb.com/cockroach/cockroach.linux-gnu-amd64.29cead1bcb4fa50eecf8cb528e25f4f963c8d2a9
chmod +x ./cockroach/cockroach
export PATH=./cockroach/:$PATH

# Make sure cockroach can be found on the path. This is required for the
# ActiveRecord Rakefile that rebuilds the test database.
export PATH=./cockroach-$VERSION.linux-amd64/:$PATH
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
  cockroach start-single-node --insecure --host=localhost --listening-url-file="$urlfile" >/dev/null 2>&1 &
  # Ensure CockroachDB is stopped on script exit.
  trap "echo 'Exit routine: Killing CockroachDB.' && kill -9 $! &> /dev/null" EXIT
  # Wait until CockroachDB has started.
  for i in {0..3}; do
    [[ -f "$urlfile" ]] && break
    backoff=$((2 ** i))
    echo "server not yet available; sleeping for $backoff seconds"
    sleep $backoff
  done
  cockroach sql --insecure -e 'CREATE DATABASE activerecord_unittest;'
  cockroach sql --insecure -e 'CREATE DATABASE activerecord_unittest2;'
}

# Install ruby dependencies.
gem install bundler:2.1.4
bundle install

run_cockroach

source ./build/test_cases.sh

HAS_FAILED=0

for test_file in ${COCKROACH_TEST_CASES[@]}; do
    echo "Running: $test_file"
    if ! (TEST_FILES="$test_file" bundle exec rake test); then
        echo "Failed: $test_file"
        HAS_FAILED=1
    else
        echo "Passed: $test_file"
    fi
done

for test_file in ${AR_TEST_CASES[@]}; do
    echo "Running: $test_file"
    if ! (TEST_FILES_AR="$test_file" bundle exec rake test); then
        echo "Failed: $test_file"
        HAS_FAILED=1
    else
        echo "Passed: $test_file"
    fi
done

# Attempt a clean shutdown for good measure. We'll force-kill in the
# exit trap if this script fails.
cockroach quit --insecure
trap - EXIT

if [ $HAS_FAILED -eq 1 ]; then
  echo "Tests failed"
  exit 1
fi
