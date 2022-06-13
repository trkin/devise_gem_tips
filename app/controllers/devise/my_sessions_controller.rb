module Devise
  class MySessionsController < SessionsController
    respond_to :json
    skip_before_action :verify_authenticity_token, if: :json_request?

    def json_request?
      request.format.json?
    end

    def create
      # TODO:
      debugger
      super
    end
    private
    # def respond_with(resource, _opts = {})
    #   debugger
    #   render json: { message: 'Logged.' }, status: :ok
    # end
    def respond_to_on_destroy
      debugger
      current_user ? log_out_success : log_out_failure
    end
    def log_out_success
      render json: { message: "Logged out." }, status: :ok
    end
    def log_out_failure
      render json: { message: "Logged out failure."}, status: :unauthorized
    end
  end
end
