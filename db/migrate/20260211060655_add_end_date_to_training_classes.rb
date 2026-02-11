class AddEndDateToTrainingClasses < ActiveRecord::Migration[8.1]
  def change
    add_column :training_classes, :end_date, :date
  end
end
