exclude :test_bulk_insert_multiple_table_with_a_multi_statement_query, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_bulk_insert_with_a_multi_statement_query_in_a_nested_transaction, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_clean_fixtures, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_auto_value_on_primary_key, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_create_fixtures, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_multiple_clean_fixtures, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_bulk_insert_with_a_multi_statement_query_raises_an_exception_when_any_insert_fails, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_inserts_with_pre_and_suffix, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"
exclude :test_create_symbol_fixtures, "Skipping the PostgreSQL test, but reimplemented for CockroachDB in test/cases/fixtures_test.rb"

module Replacement
  def test_insert_with_default_function
    before = Time.now.utc
    create_fixtures("aircrafts")
    after = Time.now.utc

    aircraft = Aircraft.find_by(name: "boeing-with-no-manufactured-at")
    assert before <= aircraft.manufactured_at && aircraft.manufactured_at <= after
  end
end

prepend Replacement
