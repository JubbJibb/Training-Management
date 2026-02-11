class CreateAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendees do |t|
      t.references :training_class, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :company
      t.text :notes

      t.timestamps null: false
    end

    add_index :attendees, [:email, :training_class_id], unique: true
  end
end
