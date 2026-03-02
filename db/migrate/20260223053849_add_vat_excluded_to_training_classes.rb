class AddVatExcludedToTrainingClasses < ActiveRecord::Migration[8.1]
  def change
    add_column :training_classes, :vat_excluded, :boolean, default: false, null: false
  end
end
