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

  def pretty_print(pp)
    # Get attributes without the unwanted one
    filtered_attrs = attributes.except("data")

    # Let pretty-print output them in the normal Rails/IRB colorized format
    pp.object_group(self) do
      filtered_attrs.each do |key, value|
        pp.breakable
        pp.text "#{key}: "
        pp.pp value
      end
    end
  end
end
