require "support/copy_cat"

# Quoting integer.
CopyCat.copy_methods(self, self, :test_relation_to_sql) do
  # From: /.?post_id.? = #{post.id}\z/i
  # To:   /.?post_id.? = '#{post.id}'\z/i
  def on_regexp(node)
    # Sanity Check
    return unless node in [:regexp, [:str, /post_id/], [:begin, [:send, [:lvar, :post], :id]], *]

    first_str, _interpolation, last_str, _regopt = node.children
    insert_after(first_str.loc.expression, ?')
    insert_before(last_str.loc.expression, ?')
  end
end
