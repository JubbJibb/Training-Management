class AddPriceAndCostFields < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :price, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :training_classes, :cost, :decimal, precision: 10, scale: 2, default: 0.0
  end
end
