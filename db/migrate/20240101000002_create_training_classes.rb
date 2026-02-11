class CreateTrainingClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :training_classes do |t|
      t.string :title, null: false
      t.text :description
      t.date :date, null: false
      t.time :start_time
      t.time :end_time
      t.string :location, null: false
      t.integer :max_attendees
      t.string :instructor

      t.timestamps null: false
    end
  end
end
