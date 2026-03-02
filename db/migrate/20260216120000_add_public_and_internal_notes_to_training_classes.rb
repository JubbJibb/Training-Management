# frozen_string_literal: true

class AddPublicAndInternalNotesToTrainingClasses < ActiveRecord::Migration[7.1]
  def change
    add_column :training_classes, :public_slug, :string
    add_column :training_classes, :public_enabled, :boolean, default: false, null: false
    add_column :training_classes, :internal_notes, :text
    add_column :training_classes, :internal_notes_updated_at, :datetime
    add_column :training_classes, :internal_notes_updated_by_id, :bigint

    add_index :training_classes, :public_slug, unique: true
    add_foreign_key :training_classes, :admin_users, column: :internal_notes_updated_by_id, on_delete: :nullify
  end
end
