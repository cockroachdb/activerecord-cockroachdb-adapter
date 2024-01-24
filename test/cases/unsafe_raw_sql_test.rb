# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/post"
require "models/comment"

module CockroachDB
  class UnsafeRawSqlTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    # OVERRIDE: We use the PostgreSQL `collation_name` for our adapter.
    test "order: allows valid arguments with COLLATE" do
      collation_name = "C" # <- Here is the overriden part.

      ids_expected = Post.order(Arel.sql(%Q'author_id, title COLLATE "#{collation_name}" DESC')).pluck(:id)

      ids = Post.order(["author_id", %Q'title COLLATE "#{collation_name}" DESC']).pluck(:id)

      assert_equal ids_expected, ids
    end
  end
end
