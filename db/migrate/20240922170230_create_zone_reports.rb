class CreateZoneReports < ActiveRecord::Migration[7.2]
  def change
    create_table :zone_reports do |t|
      t.integer :zone_id, null: false
      t.date :requested_date, null: false
      t.datetime :interval_from, null: false
      t.datetime :interval_to, null: false
      t.jsonb :data, null: false

      t.timestamps
    end
  end
end
