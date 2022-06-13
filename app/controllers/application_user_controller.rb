class ApplicationUserController < ApplicationController
  before_action :authenticate_user!

  def show_jwt
    render json: { bearer_token: request.env['warden-jwt_auth.token'] }
  end
end
