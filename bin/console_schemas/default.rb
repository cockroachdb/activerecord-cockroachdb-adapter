class Post < ActiveRecord::Base
end

ActiveRecord::Schema.define do
  create_table("posts") do |t|
    t.string :title
    t.text :body
  end

  add_index("posts", ["title"], name: "index_posts_on_title", unique: true)
end
