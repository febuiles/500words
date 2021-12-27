class CreatePosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.integer :user_id
      t.datetime :user_created_at
      t.text :text
      t.boolean :private
      t.string :location

      t.timestamps
    end
  end
end
