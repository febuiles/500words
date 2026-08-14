class RemoveUsernameFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :username, unique: true
    remove_column :users, :username, :string, null: false
  end
end
