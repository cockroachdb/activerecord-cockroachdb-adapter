# frozen_string_literal: true

require "cases/helper_cockroachdb"

class CockroachDBCachedPlanFailureTest < ActiveRecord::PostgreSQLTestCase
  FakeResult = Struct.new(:fields) do
    def result_error_field(code)
      fields[code]
    end
  end
  FakeError = Struct.new(:result)
  # The adapter is handed the ActiveRecord error and inspects its #cause,
  # which is the underlying PG error, so wrap the fake PG error accordingly.
  FakeStatementInvalid = Struct.new(:cause)

  CACHED_PLAN_MESSAGE = "cached plan must not change result type"

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def wrap(fields)
    FakeStatementInvalid.new(FakeError.new(FakeResult.new(fields)))
  end

  # CockroachDB has raised this error from "runExecBuilder" (Execute
  # phase) and, since cockroachdb/cockroach#164406, from "execBind"
  # (Bind phase). Detection must not depend on the source function.
  def test_detects_cached_plan_failure_from_any_source_function
    %w[runExecBuilder execBind].each do |source_function|
      error = wrap({
        PG::PG_DIAG_SQLSTATE => "0A000",
        PG::PG_DIAG_MESSAGE_PRIMARY => CACHED_PLAN_MESSAGE,
        PG::PG_DIAG_SOURCE_FUNCTION => source_function
      })
      assert @connection.send(:is_cached_plan_failure?, error),
        "expected cached plan failure to be detected when raised from #{source_function}"
    end
  end

  def test_detects_cached_plan_failure_with_wrapped_message
    error = wrap({
      PG::PG_DIAG_SQLSTATE => "0A000",
      PG::PG_DIAG_MESSAGE_PRIMARY => "portal \"p1\": #{CACHED_PLAN_MESSAGE}"
    })
    assert @connection.send(:is_cached_plan_failure?, error)
  end

  def test_ignores_other_feature_not_supported_errors
    error = wrap({
      PG::PG_DIAG_SQLSTATE => "0A000",
      PG::PG_DIAG_MESSAGE_PRIMARY => "unimplemented: something else"
    })
    assert_not @connection.send(:is_cached_plan_failure?, error)
  end

  def test_ignores_cached_plan_message_with_other_sqlstate
    error = wrap({
      PG::PG_DIAG_SQLSTATE => "XX000",
      PG::PG_DIAG_MESSAGE_PRIMARY => CACHED_PLAN_MESSAGE
    })
    assert_not @connection.send(:is_cached_plan_failure?, error)
  end

  def test_returns_false_when_error_fields_unavailable
    assert_not @connection.send(:is_cached_plan_failure?, FakeStatementInvalid.new(Object.new))
  end
end
