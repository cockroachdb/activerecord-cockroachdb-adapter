#!/usr/bin/env bash

set -euox pipefail

eval "$(rbenv init -)"

rbenv install --skip-existing --verbose

rbenv rehash

ruby -v

# Download CockroachDB
VERSION=v23.1.2
wget -qO- https://binaries.cockroachdb.com/cockroach-$VERSION.linux-amd64.tgz | tar xvz
readonly COCKROACH=./cockroach-$VERSION.linux-amd64/cockroach

# Make sure cockroach can be found on the path. This is required for the
# ActiveRecord Rakefile that rebuilds the test database.
export PATH=./cockroach-$VERSION.linux-amd64/:$PATH
readonly urlfile=cockroach-url

run_cockroach() {
  # Start a CockroachDB server, wait for it to become ready, and arrange
  # for it to be force-killed when the script exits.
  rm -f "$urlfile"
  rm -rf cockroach-data
  # Start CockroachDB.
  cockroach start-single-node --max-sql-memory=25% --cache=25% --insecure --host=localhost --spatial-libs=./cockroach-$VERSION.linux-amd64/lib --listening-url-file="$urlfile" >/dev/null 2>&1 &
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
  cockroach sql --insecure -e 'SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;'
  cockroach sql --insecure -e 'SET CLUSTER SETTING sql.stats.histogram_collection.enabled = false;'
  cockroach sql --insecure -e "SET CLUSTER SETTING jobs.retention_time = '180s';"
  cockroach sql --insecure -e "SET CLUSTER SETTING sql.defaults.experimental_alter_column_type.enabled = 'true'"

  cockroach sql --insecure -e "ALTER RANGE default CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 30;"
  cockroach sql --insecure -e "ALTER TABLE system.public.jobs CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 30;"
  cockroach sql --insecure -e "ALTER RANGE meta CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 30;"
  cockroach sql --insecure -e "ALTER RANGE system CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 30;"
  cockroach sql --insecure -e "ALTER RANGE liveness CONFIGURE ZONE USING num_replicas = 1, gc.ttlseconds = 30;"

  cockroach sql --insecure -e "SET CLUSTER SETTING kv.range_merge.queue_interval = '50ms'"
  cockroach sql --insecure -e "SET CLUSTER SETTING kv.raft_log.disable_synchronization_unsafe = 'true'"
  cockroach sql --insecure -e "SET CLUSTER SETTING jobs.registry.interval.cancel = '180s';"
  cockroach sql --insecure -e "SET CLUSTER SETTING jobs.registry.interval.gc = '30s';"
  cockroach sql --insecure -e "SET CLUSTER SETTING kv.range_split.by_load_merge_delay = '5s';"

  # Enable experimental features.
  cockroach sql --insecure -e "SET CLUSTER SETTING sql.defaults.experimental_temporary_tables.enabled = 'true';"
}

gem env

# Install ruby dependencies.
gem install bundler:2.4.9 rake:13.0.6

bundle install

run_cockroach

if ! (RUBYOPT="-W0" TESTOPTS="-v" bundle exec rake test); then
    echo "Tests failed"
    HAS_FAILED=1
else
    echo "Tests passed"
    HAS_FAILED=0
fi

if [ $HAS_FAILED -eq 1 ]; then
  exit 1
fi
