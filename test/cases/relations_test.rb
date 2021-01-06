# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class RelationTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_finding_with_subquery_with_eager_loading_in_from
    relation = Comment.includes(:post).where("posts.type": "Post").order(:id)
    assert_equal relation.to_a, Comment.select("*").from(relation).order(:id).to_a
    assert_equal relation.to_a, Comment.select("subquery.*").from(relation).order(:id).to_a
    assert_equal relation.to_a, Comment.select("a.*").from(relation, :a).order(:id).to_a
  end
end
