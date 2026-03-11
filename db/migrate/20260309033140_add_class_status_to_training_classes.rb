class AddClassStatusToTrainingClasses < ActiveRecord::Migration[8.1]
  def up
    add_column :training_classes, :class_status, :string, default: "private", null: false
    execute <<-SQL.squish
      UPDATE training_classes SET class_status = CASE WHEN public_enabled THEN 'public' ELSE 'private' END
    SQL
  end

  def down
    remove_column :training_classes, :class_status
  end
end
