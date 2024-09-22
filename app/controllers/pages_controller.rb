require "httparty"

class PagesController < ApplicationController
  def index
    token_response = fetch_token
    @homes_data = fetch_homes(token_response["access_token"]) if token_response["access_token"]
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

  def fetch_homes(token)
    response = HTTParty.get("https://my.tado.com/api/v2/homes/#{ENV["TADASH_MY_HOME_ID"]}", headers: { "Authorization" => "Bearer #{token}" })
    JSON.parse(response.body)
  end
end
