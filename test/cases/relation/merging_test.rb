# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/author"
require "models/categorization"
require "models/comment"
require "models/developer"
require "models/computer"
require "models/post"
require "models/project"
require "models/rating"

module CockroachDB
  # Taken from ActiveRecord. This is nearly identical except for slight modifications
  # to work in CockroachDB.
  class RelationMergingTest < ActiveRecord::TestCase
    fixtures :developers, :comments, :authors, :author_addresses, :posts

    def test_merge_doesnt_duplicate_same_clauses
      david, mary, bob = authors(:david, :mary, :bob)

      non_mary_and_bob = Author.where.not(id: [mary, bob])

      author_id = Author.connection.quote_table_name("authors.id")
      assert_sql(/WHERE #{Regexp.escape(author_id)} NOT IN \((\?|\W?\w?\d), \g<1>\)\z/) do
        assert_equal [david], non_mary_and_bob.merge(non_mary_and_bob)
      end

      only_david = Author.where("#{author_id} IN (?)", david)

      # This is the only change between this and the ActiveRecord test.
      # We need '' around the 1.
      assert_sql(/WHERE \(#{Regexp.escape(author_id)} IN \('1'\)\)\z/) do
        assert_equal [david], only_david.merge(only_david)
      end
    end
  end
end
