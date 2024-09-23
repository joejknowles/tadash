class AddAvgTempToZoneReports < ActiveRecord::Migration[7.2]
  def change
    add_column :zone_reports, :avg_temp, :decimal
    add_column :zone_reports, :avg_humidity, :decimal

    ZoneReport.all.each do |report|
      if report.data["measuredData"]["insideTemperature"]["dataPoints"].any?
        average_temperature = report.data["measuredData"]["insideTemperature"]["dataPoints"].inject(0) do |sum, datapoint|
          sum + datapoint["value"]["celsius"]
        end / report.data["measuredData"]["insideTemperature"]["dataPoints"].length
      end

      if report.data["measuredData"]["humidity"]["dataPoints"].any?
        average_humidity = report.data["measuredData"]["humidity"]["dataPoints"].inject(0) do |sum, datapoint|
          sum + datapoint["value"]
        end / report.data["measuredData"]["humidity"]["dataPoints"].length
      end

      report.update(
        avg_temp: average_temperature,
        avg_humidity: average_humidity
      )
    end
  end
end
