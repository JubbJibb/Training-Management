class CreateAttendeePromotions < ActiveRecord::Migration[8.1]
  def change
    create_table :attendee_promotions do |t|
      t.references :attendee, null: false, foreign_key: true
      t.references :promotion, null: false, foreign_key: true

      t.timestamps
    end
  end
end
