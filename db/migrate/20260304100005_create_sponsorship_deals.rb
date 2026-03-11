# frozen_string_literal: true

class CreateSponsorshipDeals < ActiveRecord::Migration[8.0]
  def change
    create_table :sponsorship_deals do |t|
      t.references :event, null: false, foreign_key: { to_table: :budget_events }
      t.string :tier
      t.decimal :amount, precision: 14, scale: 2, default: 0
      t.string :status, null: false, default: "planned"
      t.text :benefits
      t.date :deliverables_due_date
      t.text :notes

      t.timestamps
    end
    add_index :sponsorship_deals, :status
    add_index :sponsorship_deals, [:event_id, :status]
  end
end
