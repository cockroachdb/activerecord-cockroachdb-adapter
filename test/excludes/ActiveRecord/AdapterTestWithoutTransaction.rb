exclude :test_reset_empty_table_with_custom_pk, "The test fails because serial primary keys in CockroachDB are created with unique_rowid() where PostgreSQL will create them with a sequence. See https://www.cockroachlabs.com/docs/v19.2/serial.html#modes-of-operation"

require "support/copy_cat"

# This fixes a bug where our `TestRetryHelper` logic combined
# with `reset_fixtures` trying to reset a table without foreign
# keys from another table.
# It would first crash, removing the foreign key constraint (due
# to how we handle `disable_referential_integrity`). And then pass,
# since the foreign key constraint is gone. But we need that
# constraint in later tests.
#
# From:
#     fixture_names.each do |fixture_name|
#       ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, fixture_name)
#     end
#   To:
#     ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, fixture_names)
CopyCat.copy_methods(self, self, :reset_fixtures) do
  def on_block(node)
    return unless node in [:block, [:send, [:lvar, :fixture_names], :each], *]

    replace(node.loc.expression, "ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, fixture_names)")
  end
end
