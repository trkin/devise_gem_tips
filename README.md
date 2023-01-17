# Devise gem basics

Devise gem https://github.com/heartcombo/devise

## Install

You can use template.rb
```
# for new apps
rails new blog -m https://raw.githubusercontent.com/duleorlovic/devise_gem_tips/main/template.rb

# for existing apps
rails app:template LOCATION=https://raw.githubusercontent.com/duleorlovic/devise_gem_tips/main/template.rb
```

or manually copy commands from the template

or read those explanations. Start with

```
bundle add devise
rails generate devise:install
git add . && git commit -m "rails g devise:install"
```

If you do not have users table you can generate with

```
rails g devise user
last_migration
# add admin field since we will use in as sign_in_development
# t.string :name, null: false, default: ''
# t.string :locale, null: false, default: ''
# t.boolean :admin, null: false, default: false
# uncomment Trackable and Confirmable and add_index
vi app/models/user.rb # add :confirmable, :trackable
rails db:migrate
git add . && git commit -m "rails g devise user"
```

Than you need to generate views, set mailer sender and add flash to layout.

```
rails g devise:views
git add . && git commit -m "rails g devise:views"

rails credentials:edit
# for all outgoing emails: from DeviseMailer and ApplicationMailer
mailer_sender: My Company <support@example.com>

sed -i "" -e '/mailer_sender/c\
  config.mailer_sender = Rails.application.credentials.mailer_sender
' config/initializers/devise.rb

sed -i "" -e '/default from/c\
  default from: Rails.application.credentials.mailer_sender
' app/mailers/application_mailer.rb

sed -i "" -e '/yield/i\
    <p data-test="notice" class="notice"><%= notice %></p>\
    <p data-test="alert" class="alert"><%= alert %></p>\
    <%= link_to "Root", root_path %>\
    <% if current_user.present? %>\
      <span data-test="current-user-email""><%= current_user.email %></span<>\
      <%= button_to "Sign out", destroy_user_session_path, method: :delete, form_class: "d-inline" %>\
    <% else %>\
      <%= link_to "Login", new_user_session_path %>\
    <% end %>\
' app/views/layouts/application.html.erb

sed -i "" -e '/^  end/i\
    config.action_mailer.default_url_options = {host: "localhost", port: 3000}
' config/application.rb

git add . && git commit -m "Set mailer_sender and add flash"
```

Generate sample pages

```
rails g controller pages index
rails g scaffold articles title body:text
rails db:migrate
sed -i "" -e '/root..article.index/c\
  root "pages#index"
' config/routes.rb
git add . && git commit -m "Add controller pages and scaffold articles"
```

Now we will add authentication for articles pages

## Protect using ApplicationUserController

To keep it simple, I protect whole controller instead of single methods, so I
create
```
# app/controllers/application_user_controller.rb
class ApplicationUserController < ApplicationController
  before_action :authenticate_user!
end
```

and make ArticlesController inherits from it
`class ArticlesController < ApplicationUserController`.

## Turbo and Devise

When you are using Rails 7 there is an error after user is signed up
```
NoMethodError in Devise::RegistrationsController#create
undefined method `user_url' for #<Devise::RegistrationsController:0x0000000001bd00>
```

which you can solve with (no need to add now since we will add in below step)
```
# config/initializers/devise.rb
# https://github.com/heartcombo/devise/issues/5439#issuecomment-997292547
config.navigational_formats = ['*/*', :html, :turbo_stream]
```

Flash messages are not seen so we need to add two elements `TurboFailureApp` and
`TurboDeviseController`.
```
# config/initializers/devise.rb
# https://gorails.com/episodes/devise-hotwire-turbo

Rails.application.reloader.to_prepare do
  class TurboFailureApp < Devise::FailureApp # rubocop:todo Lint/ConstantDefinitionInBlock
    def respond
      if request_format == :turbo_stream
        redirect
      else
        super
      end
    end

    def skip_format?
      %w[html turbo_stream */*].include? request_format.to_s
    end
  end
end

Devise.setup do |config|
...
  config.parent_controller = 'TurboDeviseController'
  config.warden do |manager|
    manager.failure_app = TurboFailureApp
  end
  # also do not forget from above error
  config.navigational_formats = ['*/*', :html, :turbo_stream]
```

and we need this controller class (it can not be defined inside initializers
since ApplicationController does not exists yet there)
```
cat > app/controllers/turbo_devise_controller.rb << 'HERE_DOC'
class TurboDeviseController < ApplicationController
  class Responder < ActionController::Responder
    def to_turbo_stream
      controller.render(options.merge(formats: :html))
    rescue ActionView::MissingTemplate => e
      raise e if get?

      if has_errors? && default_action
        render rendering_options.merge(formats: :html, status: :unprocessable_entity)
      else
        redirect_to navigation_location
      end
    end
  end

  self.responder = Responder
  respond_to :html, :turbo_stream
end
HERE_DOC
```
and commit
```
git add . && git commit -am"Add TurboDeviseController"
```

## Sign in on development helper

Put links to be able to sign in by GET request on staging and local

```
# app/views/devise/sessions/new.html.erb
<% if Rails.env.development? %>
  <small>
    Only on development
    <dl>
      <dt>admin</dt>
      <dd>
        <% User.where(admin: true).order(:created_at).limit(5).each do |user| %>
          <%= link_to user.email, sign_in_development_path(user) %>
        <% end %>
      </dd>
      <dt>non admin</dt>
      <dd>
        <% User.where(admin: false).order(:created_at).limit(10).each do |user| %>
          <%= link_to user.email, sign_in_development_path(user) %>
        <% end %>
      </dd>
    </dl>
  </small>
<% end %>
```
and configuration
```
# app/controllers/pages_controller.rb
class PagesController < ApplicationController
  def sign_in_development
    render plain: "only_development" and return unless Rails.env.development?

    user = User.find params[:id]
    sign_in :user, user, bypass: true
    redirect_to params[:redirect_to] || root_path
  end
end

# config/routes.rb
  get 'sign-in-development/:id', to: 'pages#sign_in_development', as: :sign_in_development

# commit
git add . && git commit -am"Add sign_in_development_path"
```

# API JWT Auth

For API Auth we will use https://github.com/waiting-for-dev/devise-jwt
```
bundle add devise-jwt
rails secret
rails credentials:edit
# you need to to this for all envs: rails credentials:edit -e development
# add secret key for jwt
devise_jwt_secret_key: 123ASD
```
configure
```
# config/initializers/devise.rb
  config.jwt do |jwt|
    jwt.secret = Rails.application.credentials.devise_jwt_secret_key!
    jwt.dispatch_requests = [ ['GET', %r{^/show_jwt$}] ]
  end
```

and add to User

```
# app/models/user.rb
  devise :database_authenticatable,
    :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist
```

and create a migration and model
```
rails g migration CreateJwtDenylist
```
```
# db/migrate/20220601114003_create_jwt_denylist.rb
class CreateJwtDenylist < ActiveRecord::Migration[7.0]
  def change
    create_table :jwt_denylist do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
      t.timestamps
    end
    add_index :jwt_denylist, :jti
  end
end
```
```
cat > app/models/jwt_denylist.rb << 'HERE_DOC'
class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  self.table_name = 'jwt_denylist'
end
HERE_DOC
```

When you make a POST, and you get error like
```
ActionController::InvalidAuthenticityToken (Can't verify CSRF token authenticity.):
```
you can skip verify csrf token
```
# app/controllers/articles_controller.rb

  skip_before_action :verify_authenticity_token, if: -> { request.format.json? }
```

Or you can enable cors (not sure why this helps)

```
bundle add rack-cors
```
and create a file
```
cat > config/initializers/cors.rb << 'HERE_DOC'
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
HERE_DOC
```

Client can obtain JWT token in two ways, using html and using API.
To show Bearer jwt token on web you can use
```
# config/routes.rb
  get "show_jwt", controller: "application_user"
```
and
```
# app/controllers/application_user_controller.rb
  def show_jwt
    render json: { bearer_token: request.env['warden-jwt_auth.token'] }
  end
```

When user is logged in and navigate to `/show_jwt` response is
```
{
  bearer_token: "asd123"
}
```

Use existing controllers that are protected with
```
  before_action :authenticate_user!
```

Try in test
```
require 'devise/jwt/test_helpers'

user = User.last
headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json' }
auth_headers = Devise::JWT::TestHelpers.auth_headers(headers, user)
# {"Accept"=>"application/json",
# "Content-Type"=>"application/json",
# "Authorization"=>"Bearer eyJhbGciO..."}
get "articles", headers: auth_headers
```
for example in curl
```
export TOKEN=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI3YjgzNzUzMy0yN2JlLTRjZDQtYjNiMi1jMjY3M2UxZjQ1NjgiLCJzY3AiOiJ1c2VyIiwiYXVkIjpudWxsLCJpYXQiOjE2NTQxNTU1MDUsImV4cCI6MTY1NDE1OTEwNSwianRpIjoiOWY1OWUzODEtYzEwNy00YWMwLWI0YjMtMTQ5YjU3ODg5MzFmIn0.hB367AnlJhIaNjXAkSwWjszWYg8uRqDwtBgynSo36SQ

# list articles
curl -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" localhost:3000/articles

# create token
curl -XPOST -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" -d '{ "article": { "title": "my-title", "body": "my-body" } }' localhost:3000/articles

# delete token
curl -XDELETE -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" -H "Content-Type: application/json" localhost:3000/articles/1
```

TODO: enable sign in and sign out api
TODO: test confirmation

require 'test_helper'

class MyConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test 'sign_in after confirmation' do
    user = users(:unconfirmed)
    get user_confirmation_path(confirmation_token: user.confirmation_token)
    follow_redirect!
    assert_select "h4", "Basic Information"
  end
end

# Enable user log in with mobile phone

TODO:

## Test

Test authenticate_user

```
# test/test_helper.rb.rb
  # devise method: sign_in user
  include Devise::Test::IntegrationHelpers
```
and sign in user in tests (both in integration and system tests)
```
# test/controllers/articles_controller_test.rb
    sign_in users(:user)
```

For system tests, there is one for log in and reset password, and another for
register proccess (because register is updated more often).

