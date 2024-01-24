# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module CockroachDB
  class RelationTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    def test_finding_with_subquery_with_eager_loading_in_from
      relation = Comment.includes(:post).where("posts.type": "Post").order(:id)
      assert_equal relation.to_a, Comment.select("*").from(relation).order(:id).to_a
      assert_equal relation.to_a, Comment.select("subquery.*").from(relation).order(:id).to_a
      assert_equal relation.to_a, Comment.select("a.*").from(relation, :a).order(:id).to_a
    end

    def test_finding_with_arel_sql_order
      query = Tag.order(Arel.sql("field(id, ?)", [1, 3, 2])).to_sql
      assert_match(/field\(id, '1', '3', '2'\)/, query)

      query = Tag.order(Arel.sql("field(id, ?)", [])).to_sql
      assert_match(/field\(id, NULL\)/, query)

      query = Tag.order(Arel.sql("field(id, ?)", nil)).to_sql
      assert_match(/field\(id, NULL\)/, query)
    end
  end
end
