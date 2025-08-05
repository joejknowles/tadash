require "httparty"

class PagesController < ApplicationController
  def index
    # Aug 14th 2023 earliest? 722 on aug 5th 2025
    days_to_show = 14

    p " starting"
    # token_response = fetch_token
    token = ""
    p "got token"
    @zones = fetch_zones(token) if token
    # check if zones is correct type and has error key first:
    if @zones.is_a?(Hash) && @zones["errors"].present?
      p "Error fetching zones: #{@zones["errors"]}"
      return @error = "Error fetching zones"
    end
    @zones.each do |zone|
      p zone
      date_zone_created = zone["dateCreated"].to_date
      today = Date.today
      zone_today = ZoneReport.where(zone_id: zone["id"], requested_date: today).first
      if zone_today.present? && zone_today.is_full_day
        return
      else
        latest_full_day = ZoneReport.where(zone_id: zone["id"], is_full_day: true).order(requested_date: :desc).limit(1).first
        starting_date = latest_full_day ? latest_full_day.requested_date + 1.day : date_zone_created
        end_date = [ starting_date + 10.weeks, today ].min
        (starting_date..end_date).each do |date|
          report = fetch_zone_day_report(token, zone["id"], date)
          if report.is_a?(Hash) && report["errors"].present?
            p "Error fetching zone report: #{@zones["errors"]}"
            return @error = "Error fetching zone day report"
          end
          zone_report = ZoneReport.find_or_initialize_by(zone_id: zone["id"], requested_date: date)
          zone_report.interval_from = report["interval"]["from"]
          zone_report.interval_to = report["interval"]["to"]
          zone_report.data = report
          zone_report.is_full_day = date != today
          zone_report.save
          p "Fetched report for #{zone["name"]} on #{date}"
          sleep(0.5)
        end
      end
    end

    @temperature_data =  @zones.map do |zone|
      {
        name: zone["name"],
        data: ZoneReport.where(zone_id: zone["id"]).last(days_to_show).map { |report| [ report.requested_date, report.avg_temp ] }
      }
    end

    @min_temp = @temperature_data.map do |zone|
      zone[:data].map { |data| data[1] || Float::INFINITY }.min || Float::INFINITY
    end.min
    @max_temp = @temperature_data.map do |zone|
      zone[:data].map { |data| data[1] || 0 }.max || 0
    end.max

    @humidity_data =  @zones.map do |zone|
      {
        name: zone["name"],
        data: ZoneReport.where(zone_id: zone["id"]).last(days_to_show).map { |report| [ report.requested_date, report.avg_humidity.nil? ? nil : report.avg_humidity * 100 ] }
      }
    end

    @min_humidity = @humidity_data.map do |zone|
      zone[:data].map { |data| data[1] || Float::INFINITY }.min || Float::INFINITY
    end.min
    @max_humidity = @humidity_data.map do |zone|
      zone[:data].map { |data| data[1] || 0 }.max || 0
    end.max
  end

  def current_states
    token_response = fetch_token
    @home = fetch_home(token_response["access_token"]) if token_response["access_token"]
    @zones = fetch_zones(token_response["access_token"]) if token_response["access_token"]
    @zone_states = @zones.map do |zone|
      response = HTTParty.get("https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}/zones/#{zone["id"]}/state", headers: { "Authorization" => "Bearer #{token_response["access_token"]}" })
      JSON.parse(response.body)
    end
  end

  private

  def fetch_token
    response = HTTParty.post("https://auth.tado.com/oauth/token", body: {
      client_id: "tado-web-app",
      grant_type: "password",
      scope: "home.user",
      username: ENV["TADASH_MY_USERNAME"],
      password: ENV["TADASH_MY_PASSWORD"],
      client_secret: ENV["TADASH_TADO_CLIENT_SECRET"]
    })

    JSON.parse(response.body)
  end

  def fetch_home(token)
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}", headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end

  def fetch_zones(token)
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}/zones", headers: {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Origin" => "https://app.tado.com",
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
    })
    JSON.parse(response.body)
  end

  def fetch_zone_day_report(token, zone_id, date)
    url = "https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}/zones/#{zone_id}/dayReport?date=#{date}"
    response = HTTParty.get(url,
                            headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end
end
