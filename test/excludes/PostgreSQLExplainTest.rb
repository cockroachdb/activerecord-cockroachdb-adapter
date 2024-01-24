exclude :test_explain_with_eager_loading, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_explain_for_one_query, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"

no_options = "Explain options are not yet supported by this adapter. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/301"
exclude :test_explain_with_options_as_symbols, no_options
exclude :test_explain_with_options_as_strings, no_options
exclude :test_explain_options_with_eager_loading, no_options
