class AddUserIdToZoneReports < ActiveRecord::Migration[7.2]
  def change
    add_column :zone_reports, :user_id, :string
  end
end
