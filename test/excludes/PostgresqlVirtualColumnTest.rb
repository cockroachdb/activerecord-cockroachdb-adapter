require "support/copy_cat"

exclude :test_build_fixture_sql, "Skipping because CockroachDB cannot write directly to computed columns."
exclude :test_schema_dumping, "Replaced with local version"

# CRDB doesn't support implicit casts.
# See https://github.com/cockroachdb/cockroach/issues/75101
#
# From: "ASCII(name)"
#   To: "ASCII(name)""::string"
CopyCat.copy_methods(self, self, :test_change_table_without_stored_option) do
  def on_str(node)
    return unless node in [:str, "ASCII(name)"]

    insert_after(node.loc.expression, '"::string"')
  end
end
