require "httparty"

class LoginController < ApplicationController
  def index
    url = fetch_authorize_url

    @verification_url = url["verification_uri_complete"]
    @device_code = url["device_code"]
    flash[:notice] = nil
  end

  def token
    token_response ||= fetch_token

    @error = token_response.dig("error_description")
    if @error
      flash[:notice] = token_response.dig("error_description")
    else
      session[:tado_token] = token_response["access_token"]
      session[:tado_token_expires_at] = token_response["expires_in"].seconds.from_now - 1.minute
      session[:refresh_token] = token_response["refresh_token"]
      session[:user_id] = token_response["userId"]
      flash[:notice] = nil
      redirect_to root_path
    end
  end

  private
  def fetch_authorize_url
    response = HTTParty.post("https://login.tado.com/oauth2/device_authorize", body: {
      client_id: "1bb50063-6b0c-4d11-bd99-387f4a91cc46",
      scope: "offline_access"
    })

    JSON.parse(response.body)
  end

  def fetch_token
    response = HTTParty.post("https://login.tado.com/oauth2/token", body: {
      client_id: "1bb50063-6b0c-4d11-bd99-387f4a91cc46",
        device_code: params[:device_code],
        grant_type: "urn:ietf:params:oauth:grant-type:device_code"
    })

    JSON.parse(response.body)
  end
end
