exclude :test_legacy_change_column_with_null_executes_update, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"

module ::DefaultPrecisionImplicitTestCases
  def precision_implicit_default
    { precision: 6 }
  end
end

module Ext
  def precision_implicit_default
    { precision: 6 }
  end
end

prepend Ext
