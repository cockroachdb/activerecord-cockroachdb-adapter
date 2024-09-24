exclude :test_bind_enumerable, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_named_bind_variables, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"
exclude :test_sanitize_sql_array_handles_named_bind_variables, "Skipping until we can triage further. See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/48"

require "support/copy_cat"

# CRDB quotes ranges, like Trilogy.
CopyCat.copy_methods(self, self, :test_bind_range) do
  def on_sym(node)
    return unless node in [:sym, :TrilogyAdapter]
    replace(node.loc.expression, ":CockroachDBAdapter")
  end
end
