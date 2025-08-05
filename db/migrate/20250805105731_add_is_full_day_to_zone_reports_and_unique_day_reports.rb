class AddIsFullDayToZoneReportsAndUniqueDayReports < ActiveRecord::Migration[7.2]
  def change
    add_column :zone_reports, :is_full_day, :boolean, default: true
    add_index :zone_reports, [ :zone_id, :requested_date ], unique: true
  end
end
