# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/topic"
require "models/comment"
require "models/reply"
require "models/author"
require "models/developer"
require "models/computer"

module ActiveRecord
  module CockroachDB
    class NamedScopingTest < ActiveRecord::TestCase
      fixtures :posts, :authors, :topics, :comments, :author_addresses

      def test_reserved_scope_names
        klass = Class.new(ActiveRecord::Base) do
          self.table_name = "topics"

          scope :approved, -> { where(approved: true) }

          class << self
            public
              def pub; end

            private
              def pri; end

            protected
              def pro; end
          end
        end

        subklass = Class.new(klass)

        conflicts = [
          :create,        # public class method on AR::Base
          :relation,      # private class method on AR::Base
          :new,           # redefined class method on AR::Base
          :all,           # a default scope
          :public,        # some important methods on Module and Class
          :protected,
          :private,
          :name,
          :parent,
          :superclass
        ]

        non_conflicts = [
          :find_by_title, # dynamic finder method
          :approved,      # existing scope
          :pub,           # existing public class method
          :pri,           # existing private class method
          :pro,           # existing protected class method
          :open,          # a ::Kernel method
        ]

        conflicts.each do |name|
          e = assert_raises(ArgumentError, "scope `#{name}` should not be allowed") do
            klass.class_eval { scope name, -> { where(approved: true) } }
          end
          assert_match(/You tried to define a scope named "#{name}" on the model/, e.message)

          e = assert_raises(ArgumentError, "scope `#{name}` should not be allowed") do
            subklass.class_eval { scope name, -> { where(approved: true) } }
          end
          assert_match(/You tried to define a scope named "#{name}" on the model/, e.message)
        end

        non_conflicts.each do |name|
          assert_nothing_raised do
            silence_stream($stdout) do
              klass.class_eval { scope name, -> { where(approved: true) } }
            end
          end

          assert_nothing_raised do
            subklass.class_eval { scope name, -> { where(approved: true) } }
          end
        end
      end
    end
  end
end
