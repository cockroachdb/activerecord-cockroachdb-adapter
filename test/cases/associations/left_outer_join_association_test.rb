require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "models/post"
require "models/author"

module CockroachDB
  class LeftOuterJoinAssociationTest < ActiveRecord::TestCase
    fixtures :authors, :posts

    # This replaces the same test that's been excluded from
    # LeftOuterJoinAssociationTest. The query has been updated to guarantee the
    # result order.
    # See test/excludes/LeftOuterJoinAssociationTest.rb
    def test_construct_finder_sql_applies_aliases_tables_on_association_conditions
      result = Author.left_outer_joins(:thinking_posts, :welcome_posts).order(:id).to_a
      assert_equal authors(:david), result.first
    end

    # This replaces the same test that's been excluded from
    # LeftOuterJoinAssociationTest. The select query has been updated so the
    # integer columns are casted to strings for concatenation.
    # See test/excludes/LeftOuterJoinAssociationTest.rb
    def test_does_not_override_select
      authors = Author.select("authors.name, #{%{(authors.author_address_id::STRING || ' ' || authors.author_address_extra_id::STRING) as addr_id}}").left_outer_joins(:posts)
      assert_predicate authors, :any?
      assert_respond_to authors.first, :addr_id
    end
  end
end
