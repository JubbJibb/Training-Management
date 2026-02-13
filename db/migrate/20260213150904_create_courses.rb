# frozen_string_literal: true

class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title, null: false
      t.text :description
      t.integer :capacity
      t.string :duration_text
      t.string :category
      t.string :source_url
      t.string :external_id
      t.datetime :synced_at

      t.timestamps
    end

    add_index :courses, :external_id
    add_index :courses, :title
  end
end
