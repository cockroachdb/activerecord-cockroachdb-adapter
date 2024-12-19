# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/post"

module CockroachDB
  class ShowCreateTest < ActiveRecord::TestCase
    fixtures :posts

    def test_show_create
      assert_match(/CREATE TABLE public\.posts/, Post.show_create)
    end
  end
end
