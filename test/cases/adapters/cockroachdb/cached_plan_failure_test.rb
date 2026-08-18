# frozen_string_literal: true

require "cases/helper_cockroachdb"

class CockroachDBCachedPlanFailureTest < ActiveRecord::PostgreSQLTestCase
  FakeResult = Struct.new(:fields) do
    def result_error_field(code)
      fields[code]
    end
  end
  FakeError = Struct.new(:result)

  # Reference the adapter's constant so the tests can't drift from the
  # heuristic they are meant to verify.
  CACHED_PLAN_MESSAGE =
    ActiveRecord::ConnectionAdapters::CockroachDBAdapter::CACHED_PLAN_HEURISTIC

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  # CockroachDB has raised this error from "runExecBuilder" (Execute
  # phase) and, since cockroachdb/cockroach#164406, from "execBind"
  # (Bind phase). Detection must not depend on the source function.
  def test_detects_cached_plan_failure_from_any_source_function
    %w[runExecBuilder execBind].each do |source_function|
      pgerror = FakeError.new(FakeResult.new({
        PG::PG_DIAG_SQLSTATE => "0A000",
        PG::PG_DIAG_MESSAGE_PRIMARY => CACHED_PLAN_MESSAGE,
        PG::PG_DIAG_SOURCE_FUNCTION => source_function
      }))
      assert @connection.send(:is_cached_plan_failure?, pgerror),
        "expected cached plan failure to be detected when raised from #{source_function}"
    end
  end

  def test_detects_cached_plan_failure_with_wrapped_message
    pgerror = FakeError.new(FakeResult.new({
      PG::PG_DIAG_SQLSTATE => "0A000",
      PG::PG_DIAG_MESSAGE_PRIMARY => "portal \"p1\": #{CACHED_PLAN_MESSAGE}"
    }))
    assert @connection.send(:is_cached_plan_failure?, pgerror)
  end

  def test_ignores_other_feature_not_supported_errors
    pgerror = FakeError.new(FakeResult.new({
      PG::PG_DIAG_SQLSTATE => "0A000",
      PG::PG_DIAG_MESSAGE_PRIMARY => "unimplemented: something else"
    }))
    assert_not @connection.send(:is_cached_plan_failure?, pgerror)
  end

  def test_ignores_cached_plan_message_with_other_sqlstate
    pgerror = FakeError.new(FakeResult.new({
      PG::PG_DIAG_SQLSTATE => "XX000",
      PG::PG_DIAG_MESSAGE_PRIMARY => CACHED_PLAN_MESSAGE
    }))
    assert_not @connection.send(:is_cached_plan_failure?, pgerror)
  end

  def test_returns_false_when_error_fields_unavailable
    assert_not @connection.send(:is_cached_plan_failure?, Object.new)
  end

  # End-to-end check that a real cached-plan failure is caught and recovered
  # from against a live server, rather than only exercising the classifier
  # with fabricated errors. Adding a column changes the result type of a
  # cached `SELECT *`, which makes CockroachDB raise FEATURE_NOT_SUPPORTED
  # ("cached plan must not change result type") the next time the prepared
  # statement runs. The adapter must evict the stale statement and retry.
  #
  # Recovery only happens outside a transaction (inside one, the adapter can
  # only raise PreparedStatementCacheExpired), so this test must not run in
  # the suite's wrapping transaction.
  exclude_from_transactional_tests :test_recovers_from_real_cached_plan_failure

  def test_recovers_from_real_cached_plan_failure
    @connection.execute("DROP TABLE IF EXISTS cached_plan_things")
    @connection.execute("CREATE TABLE cached_plan_things (id INT PRIMARY KEY, a INT)")
    @connection.execute("INSERT INTO cached_plan_things (id, a) VALUES (1, 10)")

    sql = "SELECT * FROM cached_plan_things WHERE id = $1"
    bind = ActiveRecord::Relation::QueryAttribute.new(
      "id", 1, ActiveRecord::Type::Integer.new
    )

    # Prime the server-side prepared statement cache. `prepare: true` forces
    # the prepared-statement code path that contains the recovery logic.
    first = @connection.exec_query(sql, "SQL", [bind], prepare: true)
    assert_equal ["id", "a"], first.columns

    # Invalidate the cached plan by changing the result type.
    @connection.execute("ALTER TABLE cached_plan_things ADD COLUMN b INT")

    # Re-running the same prepared statement would raise without recovery;
    # the adapter should transparently flush the stale statement and retry.
    second = assert_nothing_raised do
      @connection.exec_query(sql, "SQL", [bind], prepare: true)
    end
    assert_equal ["id", "a", "b"], second.columns
    assert_equal 1, second.rows.length
  ensure
    @connection.execute("DROP TABLE IF EXISTS cached_plan_things")
    @connection.clear_cache!
  end
end
