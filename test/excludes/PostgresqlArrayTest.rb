require "support/copy_cat"

# Remove hstore from setup (both the extension and the column).
CopyCat.copy_methods(self, self, :setup) do
  def on_send(node)
    if node in [:send, nil, :enable_extension!, [:str, "hstore"], *] | # enable_extension!("hstore", ...)
               [:send, [:lvar, :t], :hstore, *] # t.hstore(...)
      remove(node.location.expression)
    end
  end
end

exclude :test_change_column_default_with_array, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_schema_dump_with_shorthand, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_change_column_from_non_array_to_array, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_with_multi_dimensional_empty_strings, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_mutate_value_in_array, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_change_column_with_array, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_multi_dimensional_with_integers, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_with_arbitrary_whitespace, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_multi_dimensional_with_strings, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
