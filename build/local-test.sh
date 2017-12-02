#!/usr/bin/env bash

set -euo pipefail

readonly urlfile=cockroach-url

# Start a CockroachDB server, wait for it to become ready, and arrange for it to
# be force-killed when the script exits.
rm -f "$urlfile"
# Clean out a past CockroachDB instance. This happens if a build was
# canceled on an agent.
rm -rf $HOME/tmp/rails &
# Start CockroachDB.
cockroach quit --insecure || true
cockroach start --insecure --host=localhost --listening-url-file="$urlfile" --store=path=$HOME/tmp/rails &
trap "echo 'Exit routine: Killing CockroachDB.' && kill -9 $! &> /dev/null" EXIT
for i in {0..3}
do
  [[ -f "$urlfile" ]] && break
  backoff=$((2 ** i))
  echo "server not yet available; sleeping for $backoff seconds"
  sleep $backoff
done

# Target the Rails dependency file.
export BUNDLE_GEMFILE=$(pwd)/rails/Gemfile

# Run the tests.
cp build/config.teamcity.yml rails/activerecord/test/config.yml
echo "Rebuilding database"
(cd rails/activerecord && bundle exec rake db:cockroachdb:rebuild)
echo "Starting tests"
(cd rails/activerecord && bundle exec rake test:cockroachdb TESTFILES=$1)

# Attempt a clean shutdown for good measure. We'll force-kill in the atexit
# handler if this fails.
cockroach quit --insecure
trap - EXIT
