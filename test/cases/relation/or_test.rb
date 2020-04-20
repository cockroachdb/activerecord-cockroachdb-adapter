# This test has been copied to fix a bug in the test setup. It can be removed
# once the bugfix has been released in Rails - see rails/rails#38978.
# See test/excludes/OrTest.rb

require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "models/post"
require "models/author"
require "models/categorization"

module CockroachDB
  module ActiveRecord
    class OrTest < ActiveRecord::TestCase
      fixtures :posts
      fixtures :authors, :author_addresses

      def test_or_when_grouping
        groups = Post.where("id < 10").group("body")
        expected = groups.having("COUNT(*) > 1 OR body like 'Such%'").count
        assert_equal expected, groups.having("COUNT(*) > 1").or(groups.having("body like 'Such%'")).count
      end
    end
  end
end
