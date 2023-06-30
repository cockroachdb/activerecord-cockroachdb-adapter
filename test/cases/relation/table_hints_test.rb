# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/post"

module CockroachDB
  class TableHintsTest < ActiveRecord::TestCase
    fixtures :posts

    def test_add_hint
      force_index = ->(q) { q.force_index("index_posts_on_author_id") }
      index_hint = ->(q) { q.index_hint("NO_FULL_SCAN") }

      assert_sql(/"posts"@\{FORCE_INDEX=index_posts_on_author_id\}/) do
        Post.then(&force_index).take
      end

      assert_sql(/"posts"@\{NO_FULL_SCAN\}/) do
        Post.then(&index_hint).take
      end

      [force_index, index_hint].permutation do |procs|
        assert_sql(/"posts"@\{NO_FULL_SCAN,FORCE_INDEX=index_posts_on_author_id\}/) do
          Post.then(&procs.reduce(:<<)).take
        end
      end
    end

    def test_choose_index_order
      idx = "index_posts_on_author_id"
      assert_sql(/"posts"@\{FORCE_INDEX=#{idx},ASC\}/) do
        Post.force_index(idx, direction: "ASC").take
      end
      assert_sql(/"posts"@\{FORCE_INDEX=#{idx},DESC\}/) do
        Post.force_index(idx, direction: "DESC").take
      end
      assert_sql(/"posts"@\{NO_FULL_SCAN,FORCE_INDEX=#{idx},DESC\}/) do
        Post.force_index(idx, direction: "DESC").index_hint("NO_FULL_SCAN").take
      end
    end

    def test_use_other_table
      force_index = ->(q) { q.force_index("index_subscribers_on_nick") }
      index_hint = ->(q) { q.index_hint("NO_FULL_SCAN") }
      post_from = Post.select(:id).from("subscribers")

      assert_sql(/subscribers@\{FORCE_INDEX=index_subscribers_on_nick\}/) do
        post_from.then(&force_index).take
      end

      assert_sql(/subscribers@\{NO_FULL_SCAN\}/) do
        post_from.then(&index_hint).take
      end

      [force_index, index_hint].permutation do |procs|
        assert_sql(/subscribers@\{NO_FULL_SCAN,FORCE_INDEX=index_subscribers_on_nick\}/) do
          post_from.then(&procs.reduce(:<<)).take
        end
      end
    end

    def test_from_with_space
      ["foo\t", "foo  "].each do
        assert_match(/FROM foo@\{H\}/, Post.from(_1).index_hint("H").to_sql)
        assert_match(
          /FROM foo@\{H,FORCE_INDEX=i\}/,
          Post.from(_1).index_hint("H").force_index("i").to_sql
        )
      end
    end

    def test_reset_with_from
      force_index = ->(q) { q.force_index("type") }
      index_hint = ->(q) { q.index_hint("NO_FULL_SCAN") }

      [force_index, index_hint].permutation do
        assert_match(
          /FROM age\z/,
          Post.then(&_1).then(&_2).from("age").to_sql
        )
      end
      [force_index, index_hint].each do
        assert_match(/FROM age\z/, Post.then(&_1).from("age").to_sql)
      end

    end

    def test_ignore_from_multiple_tables
      tables = "ta, tb"
      from = ->(q) { q.from(tables) }
      force_index = ->(q) { q.force_index("type") }
      index_hint = ->(q) { q.index_hint("NO_FULL_SCAN") }

      (
        [from, force_index, index_hint].permutation +
        [from, force_index].permutation +
        [from, index_hint].permutation
      ).each do |procs|
        assert_match(
          /FROM #{tables}\z/,
          Post.then(&procs.reduce(:<<)).to_sql
        )
      end
    end

    def test_ignore_from_subquery
      subquery = Post.where("created_at < ?", 1.year.ago)
      from = ->(q) { q.from(subquery) }
      force_index = ->(q) { q.force_index("safeword") }
      index_hint = ->(q) { q.index_hint("NO_FULL_SCAN") }

      (
        [from, force_index, index_hint].permutation +
        [from, force_index].permutation +
        [from, index_hint].permutation
      ).each do |procs|
        refute_match(
          /safeword|NO_FULL_SCAN|@/,
          Post.then(&procs.reduce(:<<)).to_sql
        )
      end
    end
  end
end
