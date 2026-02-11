class CreatePromotions < ActiveRecord::Migration[8.1]
  def change
    create_table :promotions do |t|
      t.string :name, null: false
      t.string :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 2, default: 0.0
      t.text :description
      t.boolean :active, default: true
      t.decimal :base_price, precision: 10, scale: 2, default: 0.0

      t.timestamps
    end
  end
end
