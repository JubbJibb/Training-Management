class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name, null: false
      t.string :participant_type
      t.string :company
      t.string :email, null: false
      t.string :phone
      t.string :tax_id
      t.string :billing_name
      t.text :billing_address

      t.timestamps
    end

    add_index :customers, :email, unique: true
    add_index :customers, :tax_id
  end
end
