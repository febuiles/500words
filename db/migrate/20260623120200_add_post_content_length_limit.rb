class AddPostContentLengthLimit < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :posts, "length(content) <= 50000", name: "posts_content_max_length"
  end
end
