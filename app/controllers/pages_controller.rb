require "httparty"

class PagesController < ApplicationController
  def index
    token_response = fetch_token
    @zones = fetch_zones(token_response["access_token"]) if token_response["access_token"]
    @zones.each do |zone|
      date_zone_created = zone["dateCreated"].to_date
      yesterday = Date.yesterday
      zone_yesterday = ZoneReport.where(zone_id: zone["id"], requested_date: yesterday).first
      if zone_yesterday.present?
        zone_yesterday.requested_date
      else
        latest_existing = ZoneReport.where(zone_id: zone["id"]).order(requested_date: :desc).limit(1).first
        starting_date = latest_existing ? latest_existing.requested_date + 1.day : date_zone_created
        end_date = [ starting_date + 10.weeks, yesterday ].min
        (starting_date..end_date).each do |date|
          report = fetch_zone_day_report(token_response["access_token"], zone["id"], date)
          new_report = ZoneReport.create(zone_id: zone["id"], requested_date: date, interval_from: report["interval"]["from"], interval_to: report["interval"]["to"], data: report)
          p "Fetched report for #{zone["name"]} on #{date}"
          sleep(0.5)
          new_report.requested_date
        end
      end
    end

    @temperature_data =  @zones.map do |zone|
      {
        name: zone["name"],
        data: ZoneReport.where(zone_id: zone["id"]).map { |report| [ report.requested_date, report.avg_temp ] }
      }
    end

    @humidity_data =  @zones.map do |zone|
      {
        name: zone["name"],
        data: ZoneReport.where(zone_id: zone["id"]).map { |report| [ report.requested_date, report.avg_humidity ] }
      }
    end
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
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}/zones", headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end

  def fetch_zone_day_report(token, zone_id, date)
    url = "https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}/zones/#{zone_id}/dayReport?date=#{date}"
    response = HTTParty.get(url,
                            headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end
end
