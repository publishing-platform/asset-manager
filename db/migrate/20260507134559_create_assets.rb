class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.uuid :uuid, null: false
      t.datetime :deleted_at, precision: nil
      t.string :state, null: false, default: "unscanned"
      t.string :file
      t.jsonb :filename_history, null: false, default: []
      t.boolean :draft, default: false, null: false
      t.string :redirect_url
      t.string :etag
      t.string :md5_hexdigest
      t.integer :size
      t.string :content_type
      t.string :parent_document_url
      t.datetime :last_modified, precision: nil
      t.jsonb :auth_bypass_ids, null: false, default: []
      t.references :replaced_by, foreign_key: { to_table: :assets, on_delete: :restrict }
      t.timestamps

      t.index :deleted_at
      t.index :uuid, unique: true
    end
  end
end
