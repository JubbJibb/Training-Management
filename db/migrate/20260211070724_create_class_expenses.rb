class CreateClassExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :class_expenses do |t|
      t.references :training_class, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :amount, precision: 10, scale: 2, default: 0.0, null: false
      t.string :category

      t.timestamps
    end
  end
end
