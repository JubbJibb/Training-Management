class AddAcquisitionChannelToCustomers < ActiveRecord::Migration[8.1]
  def up
    add_column :customers, :acquisition_channel, :string
    Customer.reset_column_information
    Customer.where(acquisition_channel: nil).update_all(acquisition_channel: "unknown")
  end

  def down
    remove_column :customers, :acquisition_channel, :string
  end
end
