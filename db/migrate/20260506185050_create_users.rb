class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :uid
      t.string :organisation_slug
      t.string :organisation_content_id
      t.text :permissions
      t.boolean :disabled, default: false

      t.timestamps
    end
  end
end
