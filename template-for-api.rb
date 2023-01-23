# Install devise-jwt
run <<BASH
bundle add devise-jwt
BASH

# Add devise_jwt_secret_key to credentials and configure devise to use it
run <<'BASH'
set -e # Any commands which fail will cause the shell script to exit immediately
set -x # Show command being executed

EDITOR='echo "devise_jwt_secret_key: '"`rails secret`"'" >> ' rails credentials:edit

rails runner "puts Rails.application.credentials.devise_jwt_secret_key!"
BASH

insert_into_file 'config/initializers/devise.rb', <<-HERE_DOC, after: "Devise.setup do |config|\n"
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.dispatch_requests = [ ['GET', %r{^/show_jwt$}] ]
  end
HERE_DOC

# Create JwtDenylist model and add `jwt_authenticatable` to User
insert_into_file "config/application.rb", <<'HERE_DOC', before: /^  end$/

    # https://github.com/rails/rails/pull/31448#issuecomment-1399214463
    # Add `, null: false` on `t.` lines. Replace `jti` and `exp` with your names
    # EDITOR_FOR_GENERATOR='sed -i "" -r -e "/^[[:space:]]*t.*(jti|exp)$/ s/$/, null: false/"' rails g model JwtDenylist jti:index exp:datetime:index
    config.generators.after_generate do |files|
      if ENV["EDITOR_FOR_GENERATOR"]
        files.each do |file|
          system("#{ENV["EDITOR_FOR_GENERATOR"]} #{file}")
        end
      end
    end
HERE_DOC

run <<'BASH'
# add `, null: false` to migration lines that begins with `t.* jti|exp`
EDITOR_FOR_GENERATOR='sed -i "" -r -e "/^[[:space:]]*t.*(jti|exp)$/ s/$/, null: false/"' rails g model JwtDenylist jti:index exp:datetime:index

rails db:migrate
BASH

insert_into_file 'app/models/jwt_denylist.rb', <<-HERE_DOC, after: "ApplicationRecord\n"
  include Devise::JWT::RevocationStrategies::Denylist
HERE_DOC

insert_into_file 'app/models/user.rb', <<-HERE_DOC, after: "validatable"
,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
HERE_DOC

insert_into_file 

# on a POST we need to skip verify csrf token
insert_into_file "app/controllers/application_controller.rb", <<~HERE_DOC, after: "Base\n"
  # On POST and json there is an error so we need to skip this verification
  # ActionController::InvalidAuthenticityToken (Can't verify CSRF token authenticity.):
  skip_before_action :verify_authenticity_token, if: -> { request.format.json?  && request.post? }
HERE_DOC
