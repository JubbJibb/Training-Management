# frozen_string_literal: true

class CreateFinancialActionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_action_logs do |t|
      t.string :action_type, null: false
      t.integer :actor_id
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :metadata
      t.string :status, null: false, default: "queued"
      t.text :error_message

      t.timestamps
    end

    add_index :financial_action_logs, [:subject_type, :subject_id]
    add_index :financial_action_logs, :actor_id
    add_index :financial_action_logs, :action_type
    add_index :financial_action_logs, :status
    add_index :financial_action_logs, :created_at
  end
end
