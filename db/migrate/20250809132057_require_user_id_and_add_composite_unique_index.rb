class RequireUserIdAndAddCompositeUniqueIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  OLD_NAME = "index_zone_reports_on_zone_id_and_requested_date"
  NEW_NAME = "index_zone_reports_on_user_id_zone_id_requested_date"

  def up
    # 1) Enforce NOT NULL (after backfilling existing records)
    change_column_null :zone_reports, :user_id, false

    # 2) Add new unique composite index concurrently
    add_index :zone_reports,
              [ :user_id, :zone_id, :requested_date ],
              unique: true,
              algorithm: :concurrently,
              name: NEW_NAME

    # 3) Drop old unique index if present
    if index_exists?(:zone_reports, [ :zone_id, :requested_date ])
      remove_index :zone_reports, column: [ :zone_id, :requested_date ]
    elsif index_exists_by_name?(:zone_reports, OLD_NAME)
      remove_index :zone_reports, name: OLD_NAME
    end
  end

  def down
    # Restore old unique index
    add_index :zone_reports, [ :zone_id, :requested_date ], unique: true, name: OLD_NAME

    # Remove new index
    remove_index :zone_reports, name: NEW_NAME

    # Allow nulls again
    change_column_null :zone_reports, :user_id, true
  end

  private

  def index_exists_by_name?(table, name)
    connection.indexes(table).any? { |i| i.name == name }
  end
end
