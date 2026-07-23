class AddTitleAndNumberToPosts < ActiveRecord::Migration[8.1]
  def up
    add_column :posts, :title, :string
    add_column :posts, :number, :integer

    # Backfill per-user sequence numbers in creation order.
    execute <<~SQL
      UPDATE posts SET number = (
        SELECT COUNT(*) FROM posts AS earlier
        WHERE earlier.user_id = posts.user_id
          AND (earlier.created_at < posts.created_at
               OR (earlier.created_at = posts.created_at AND earlier.id <= posts.id))
      )
    SQL

    change_column_null :posts, :number, false
    add_index :posts, [:user_id, :number], unique: true
  end

  def down
    remove_index :posts, column: [:user_id, :number]
    remove_column :posts, :number
    remove_column :posts, :title
  end
end
