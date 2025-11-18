require "support/copy_cat"

# We override this test since in our codebase, there is a SCHEMA call
# made with `SHOW max_identifier_length`.
# TODO: We should however inspect why that is.
#
# See https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/392
#
# From: notification.first
#   To: notification.last
CopyCat.copy_methods(self, self, :test_payload_name_on_eager_load) do
  def on_send(node)
    return super unless node in [:send, [:lvar, :notification], :first]
    replace(node.loc.expression, "notification.last")
  end
end
