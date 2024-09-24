require "support/copy_cat"

# CockroachDB quotes numbers as strings.
CopyCat.copy_methods(self, self,
  :test_where_with_float_for_string_column_using_bind_parameters,
  :test_where_with_decimal_for_string_column_using_bind_parameters,
  :test_where_with_rational_for_string_column_using_bind_parameters,
  :test_where_with_integer_for_string_column_using_bind_parameters) do
  def on_str(node)
    str = node.children[0]
    return unless ["0.0", "0", "0/1"].include?(str)

    replace(node.loc.expression, "'#{str}'".inspect)
  end
end
