require "httparty"

class PagesController < ApplicationController
  def index
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
end
