# frozen_string_literal: true

require "cases/helper"
require "models/topic"

module CockroachDB
  class PersistenceTest < ActiveRecord::TestCase
    fixtures :topics

    self.use_transactional_tests = false

    # This test is identical to the one found in Rails, except we need to run
    # it with transactions turned off in order to properly assert on the newly
    # added column.
    def test_reset_column_information_resets_children
      child_class = Class.new(Topic)
      child_class.new # force schema to load

      ActiveRecord::Base.connection.add_column(:topics, :foo, :string)
      Topic.reset_column_information

      # this should redefine attribute methods
      child_class.new

      assert child_class.instance_methods.include?(:foo)
      assert child_class.instance_methods.include?(:foo_changed?)
      assert_equal "bar", child_class.new(foo: :bar).foo
    ensure
      ActiveRecord::Base.connection.remove_column(:topics, :foo)
      Topic.reset_column_information
    end
  end
end
