class Post < ActiveRecord::Base
end

ActiveRecord::Schema.define do
  create_table("posts") do |t|
    t.string :title
    t.text :body
  end
end
