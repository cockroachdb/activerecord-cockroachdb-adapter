class Post < ActiveRecord::Base
  self.table_name = "bar.posts"
end

class Comment < ActiveRecord::Base
  self.table_name = "foo.comments"
end

ActiveRecord::Schema.define do
  create_schema("foo")
  create_schema("bar")
  create_table("bar.posts") do |t|
    t.string :title
    t.text :body
  end

  create_table("foo.comments") do |t|
    t.integer :post_id
    t.text :body
  end

  add_foreign_key "foo.comments", "bar.posts", column: "post_id"
end
