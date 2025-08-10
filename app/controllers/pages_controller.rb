require "httparty"

class PagesController < ApplicationController
  DEFAULT_DAYS_TO_SHOW = 14

  def index
    # Aug 14th 2023 earliest? 722 on aug 5th 2025
    @days_to_show = params[:days_to_show].to_i > 0 ? params[:days_to_show].to_i : DEFAULT_DAYS_TO_SHOW

    token = session[:tado_token]

    if token.nil? || session[:tado_token_expires_at].nil? || session[:user_id].nil?
      @error = "auth/no_token"
      p "No token found in session"
      return redirect_to login_path
    elsif session[:tado_token_expires_at].nil? || session[:tado_token_expires_at] < Time.current
      p "Token expired, fetching new token"
      token = fetch_refresh_token
      if token.nil?
        @error = "auth/expired_token"
        return redirect_to login_path
      end
    else
      p "Using existing token"
    end

    @zones = fetch_zones(token)
    # check if zones is correct type and has error key first:
    if @zones.is_a?(Hash) && @zones["errors"].present?
      p "Error fetching zones: #{@zones["errors"]}"
      session[:tado_token] = nil
      @error = "auth/expired_token"
      return redirect_to login_path
    end
    @zones.each do |zone|
      date_zone_created = zone["dateCreated"].to_date
      today = Date.today
      zone_today = ZoneReport.where(user_id: session[:user_id], zone_id: zone["id"], requested_date: today).first
      if zone_today.present? && (zone_today.is_full_day || zone_today.updated_at > 10.minutes.ago)
        next
      else
        latest_full_day = ZoneReport.where(
          user_id: session[:user_id],
          zone_id: zone["id"],
          is_full_day: true
        ).order(requested_date: :desc).limit(1).first
        starting_date = latest_full_day ? latest_full_day.requested_date + 1.day : date_zone_created
        end_date = [ starting_date + 10.weeks, today ].min
        (starting_date..end_date).each do |date|
          report = fetch_zone_day_report(token, zone["id"], date)
          if report.is_a?(Hash) && report["errors"].present?
            p "Error fetching zone report: #{@zones["errors"]}"
            return @error = "Error fetching zone day report"
          end
          zone_report = ZoneReport.find_or_initialize_by(zone_id: zone["id"], requested_date: date, user_id: session[:user_id])
          zone_report.interval_from = report["interval"]["from"]
          zone_report.interval_to = report["interval"]["to"]
          zone_report.data = report
          zone_report.is_full_day = date != today
          zone_report.user_id = session[:user_id]
          zone_report.save!
          p "Fetched report for #{zone["name"]} on #{date}"
          sleep(0.5) if starting_date != end_date
        end
      end
    end

    @temperature_data =  @zones.map do |zone|
      {
        name: zone["name"],
        data: ZoneReport.where(
          zone_id: zone["id"],
          user_id: session[:user_id],
          requested_date: (Date.today - @days_to_show.days)..Date.today
        ).map { |report| [ report.requested_date, report.avg_temp ] }
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
        data: ZoneReport.where(
          zone_id: zone["id"],
          user_id: session[:user_id],
          requested_date: (Date.today - @days_to_show.days)..Date.today
        ).map { |report| [ report.requested_date, report.avg_humidity.nil? ? nil : report.avg_humidity * 100 ] }
      }
    end

    @min_humidity = @humidity_data.map do |zone|
      zone[:data].map { |data| data[1] || Float::INFINITY }.min || Float::INFINITY
    end.min
    @max_humidity = @humidity_data.map do |zone|
      zone[:data].map { |data| data[1] || 0 }.max || 0
    end.max

    p "Finished fetching data"
  end

  def current_states
    token_response = fetch_token
    @home = fetch_home(token_response["access_token"]) if token_response["access_token"]
    @zones = fetch_zones(token_response["access_token"]) if token_response["access_token"]
    @zone_states = @zones.map do |zone|
      response = HTTParty.get("https://my.tado.com/api/v2/homes/#{session[:tado_home_id]}/zones/#{zone["id"]}/state", headers: { "Authorization" => "Bearer #{token_response["access_token"]}" })
      JSON.parse(response.body)
    end
  end

  private


  def fetch_refresh_token
    response = HTTParty.post("https://login.tado.com/oauth2/token", body: {
        client_id: "1bb50063-6b0c-4d11-bd99-387f4a91cc46",
        refresh_token: session[:refresh_token],
        grant_type: "refresh_token"
    })

    token_response = JSON.parse(response.body)

    return p token_response["error_description"] if token_response["error_description"]

    session[:tado_token] = token_response["access_token"]
    session[:refresh_token] = token_response["refresh_token"]
    session[:tado_token_expires_at] = token_response["expires_in"].seconds.from_now - 1.minute
    session[:user_id] = token_response["userId"]

    home_response = fetch_home(token_response["access_token"])
      session[:tado_home_id] = home_response["homes"][0]["id"]

    token_response["access_token"]
  end

  def fetch_home(token)
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{session[:tado_home_id]}", headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end

  def fetch_zones(token)
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{session[:tado_home_id]}/zones", headers: {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Origin" => "https://app.tado.com",
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
    })
    JSON.parse(response.body)
  end

  def fetch_zone_day_report(token, zone_id, date)
    url = "https://my.tado.com/api/v2/homes/#{session[:tado_home_id]}/zones/#{zone_id}/dayReport?date=#{date}"
    response = HTTParty.get(url,
                            headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end

  def fetch_home(token)
    response = HTTParty.get("https://my.tado.com/api/v2/me", headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end
end
