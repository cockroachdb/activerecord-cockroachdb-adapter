# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/post"
require "models/comment"

module CockroachDB
  class AostTest < ActiveRecord::TestCase
    def test_simple_aost
      time = 2.days.ago
      re_time = Regexp.quote(time.iso8601)
      assert_match(/from "posts" as of system time '#{re_time}'/i, Post.aost(time).to_sql)
      assert_match(/from "posts" as of system time '#{re_time}'/i, Post.where(name: "foo").aost(time).to_sql)
    end

    def test_reset_aost
      time = 1.second.from_now
      assert_match(/from "posts"\z/i, Post.aost(time).aost(nil).to_sql)
    end

    def test_aost_with_join
      time = Time.now
      assert_match(
        /FROM "posts" INNER JOIN "comments" ON "comments"."post_id" = "posts"."id" AS OF SYSTEM TIME '#{Regexp.quote time.iso8601}'/,
        Post.joins(:comments).aost(time).to_sql
      )
    end

    def test_aost_with_subquery
      time = 4.seconds.ago
      assert_match(/from \(.*?\) subquery as of system time '#{Regexp.quote time.iso8601}'/i, Post.from(Post.where(name: "foo")).aost(time).to_sql)
    end

    def test_only_time_input
      time = 1.second.ago
      expected = "SELECT \"posts\".* FROM \"posts\" AS OF SYSTEM TIME '#{time.iso8601}'"
      assert_equal expected, Post.aost(time).to_sql
      assert_raises(ArgumentError) { Post.aost("no time") }
      assert_raises(ArgumentError) { Post.aost(true) }
    end
  end

  class AostNoTransactionTest < ActiveRecord::TestCase
    # AOST per query is not compatible with transactions.
    self.use_transactional_tests = false

    def test_aost_with_multiple_queries
      time = 1.second.ago
      queries = capture_sql {
        Post.aost(time).limit(2).find_each(batch_size: 1).to_a
      }
      queries.each do
        assert_match /FROM \"posts\" AS OF SYSTEM TIME '#{Regexp.quote time.iso8601}'/, _1
      end
    end
  end
end
