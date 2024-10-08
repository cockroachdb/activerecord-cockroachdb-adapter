# frozen_string_literal: true
#
# Adapted from https://github.com/rails/rails/blob/main/guides/bug_report_templates/active_record.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "activerecord"

  gem "activerecord-cockroachdb-adapter"
end

require "activerecord-cockroachdb-adapter"
require "minitest/autorun"
require "logger"

# You might want to change the database name for another one.
ActiveRecord::Base.establish_connection("cockroachdb://root@localhost:26257/defaultdb")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class BugTest < ActiveSupport::TestCase
  def test_association_stuff
    post = Post.create!
    post.comments << Comment.create!

    assert_equal 1, post.comments.count
    assert_equal 1, Comment.count
    assert_equal post.id, Comment.first.post.id
  end
end
