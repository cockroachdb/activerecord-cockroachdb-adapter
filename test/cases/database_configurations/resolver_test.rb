# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "support/copy_cat"

module CockroachDB
  class ResolverTest < ::ActiveRecord::ConnectionAdapters::PoolConfig::ResolverTest
    CopyCat.copy_methods(self, ::ActiveRecord::ConnectionAdapters::PoolConfig::ResolverTest,
      :test_url_invalid_adapter) do
        # We're not in the ActiveRecord namespace anymore.
        def on_const(node)
          return unless node in [:const, nil, :AdapterNotFound|:Base]

          insert_before(node.loc.expression, "ActiveRecord::")
        end

        def on_str(node)
          return unless node in [:str, /\ADatabase config/]

          replace(node.loc.expression, node.children.first.sub("abstract,", "abstract, cockroachdb,").inspect)
        end
    end
  end
end
