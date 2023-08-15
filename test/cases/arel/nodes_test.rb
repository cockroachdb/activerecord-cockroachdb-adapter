# frozen_string_literal: true
# This file may be remove after next
# rails release.
# Whenever https://github.com/rails/rails/commit/8bd463c
# is part of a rails version.

require "cases/arel/helper"

module Arel
  module Nodes
    class TestNodes < Arel::Test
      def test_every_arel_nodes_have_hash_eql_eqeq_from_same_class
        # #descendants code from activesupport
        node_descendants = []
        ObjectSpace.each_object(Arel::Nodes::Node.singleton_class) do |k|
          next if k.respond_to?(:singleton_class?) && k.singleton_class?
          node_descendants.unshift k unless k == self
        end
        node_descendants.delete(Arel::Nodes::Node)
        node_descendants.delete(Arel::Nodes::NodeExpression)

        default_hash_owner = Object.instance_method(:hash).owner

        bad_node_descendants = node_descendants.reject do |subnode|
          eqeq_owner = subnode.instance_method(:==).owner
          eql_owner = subnode.instance_method(:eql?).owner
          hash_owner = subnode.instance_method(:hash).owner

          hash_owner != default_hash_owner &&
              eqeq_owner == eql_owner &&
              eqeq_owner == hash_owner
        end

        problem_msg = "Some subclasses of Arel::Nodes::Node do not have a" \
            " #== or #eql? or #hash defined from the same class as the others"
        assert_empty bad_node_descendants, problem_msg
      end
    end
  end
end
