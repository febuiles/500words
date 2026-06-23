class AddIntegrityConstraints < ActiveRecord::Migration[8.1]
  def up
    # Users: enforce presence and uniqueness at the database level so a
    # validation race can't create duplicate or partial accounts.
    change_column_null :users, :email, false
    change_column_null :users, :username, false
    change_column_null :users, :password_digest, false

    remove_index :users, :email
    add_index :users, :email, unique: true
    add_index :users, :username, unique: true

    # Posts: content and word_count must always be present; word_count is a
    # non-negative count with a safe default.
    change_column_null :posts, :content, false
    change_column_default :posts, :word_count, from: nil, to: 0
    change_column_null :posts, :word_count, false
    add_check_constraint :posts, "word_count >= 0", name: "posts_word_count_non_negative"
  end

  def down
    remove_check_constraint :posts, name: "posts_word_count_non_negative"
    change_column_null :posts, :word_count, true
    change_column_default :posts, :word_count, from: 0, to: nil
    change_column_null :posts, :content, true

    remove_index :users, :username
    remove_index :users, :email
    add_index :users, :email

    change_column_null :users, :password_digest, true
    change_column_null :users, :username, true
    change_column_null :users, :email, true
  end
end
