# frozen_string_literal: true

class CreateBudgetEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_events do |t|
      t.string :name, null: false
      t.string :organizer
      t.date :start_date
      t.date :end_date
      t.string :location
      t.text :objective
      t.string :owner_name
      t.text :notes

      t.timestamps
    end
    add_index :budget_events, :start_date
  end
end
