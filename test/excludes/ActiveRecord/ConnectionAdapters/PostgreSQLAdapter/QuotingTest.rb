comment = "This adapter quotes integers as string, as CRDB is capable of " \
  "implicitely converting, and checking for out of bound errors. " \
  "See quoting.rb for more information."
exclude :test_do_not_raise_when_int_is_not_wider_than_64bit, comment
exclude :test_do_not_raise_when_raise_int_wider_than_64bit_is_false, comment
exclude :test_raise_when_int_is_wider_than_64bit, comment

require "support/copy_cat"

CopyCat.copy_methods(self, self,
  :test_quote_big_decimal,
  :test_quote_rational,
  :test_quote_integer) do
  def on_str(node)
    return if defined?(@already_quoted)
    @already_quoted = true
    node => [:str, str]
    return unless ["4.2", "3/4", "42"].include?(str)

    replace(node.loc.expression, "'#{str}'".inspect)
  end
end
