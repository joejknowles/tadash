class ZoneReport < ApplicationRecord
  after_create :add_averages

  def add_averages
    if data["measuredData"]["insideTemperature"]["dataPoints"].any?
      average_temperature = data["measuredData"]["insideTemperature"]["dataPoints"].inject(0) do |sum, datapoint|
        sum + datapoint["value"]["celsius"]
      end / data["measuredData"]["insideTemperature"]["dataPoints"].length
    end

    if data["measuredData"]["humidity"]["dataPoints"].any?
      average_humidity = data["measuredData"]["humidity"]["dataPoints"].inject(0) do |sum, datapoint|
        sum + datapoint["value"]
      end / data["measuredData"]["humidity"]["dataPoints"].length
    end

    self.update(
      avg_temp: average_temperature,
      avg_humidity: average_humidity
    )
  end
end
