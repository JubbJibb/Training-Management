class AddCustomerToAttendees < ActiveRecord::Migration[8.1]
  # This migration may be run after a partial failure (e.g., column/index created but
  # migration not recorded). Make it idempotent so `db:migrate` can succeed.
  def up
    unless column_exists?(:attendees, :customer_id)
      # Allow NULL initially so existing rows can be backfilled safely.
      add_reference :attendees, :customer, null: true, foreign_key: true
    end

    unless index_exists?(:attendees, :customer_id)
      add_index :attendees, :customer_id
    end

    unless foreign_key_exists?(:attendees, :customers)
      add_foreign_key :attendees, :customers
    end
  end

  def down
    remove_foreign_key :attendees, :customers if foreign_key_exists?(:attendees, :customers)
    remove_index :attendees, :customer_id if index_exists?(:attendees, :customer_id)
    remove_column :attendees, :customer_id if column_exists?(:attendees, :customer_id)
  end
end
