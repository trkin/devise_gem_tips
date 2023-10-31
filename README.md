# Devise gem basics

Devise gem https://github.com/heartcombo/devise

## Install

You can use template.rb
```
# for new apps
rails new blog -m https://raw.githubusercontent.com/trkin/devise_gem_tips/main/template.rb

# for new apps but using local copy of template instead of github version
rails new blog -m ~/web-tips/devise_gem_tips/template.rb

# for existing apps
rails app:template LOCATION=https://raw.githubusercontent.com/trkin/devise_gem_tips/main/template.rb

# for existing apps but using local copy of template instead of github version
rails app:template LOCATION=~/web-tips/devise_gem_tips/template.rb
```

You can read commands from the template and manually copy paste each one.
In template you can see the blocks like:

* Generate default user model if you do not already have users table. Note that
  for uuid you first need to enable extension <https://github.com/trkin/rails_uuid_as_primary_key>
* Use [Const](https://github.com/duleorlovic/rails_helpers_and_const/blob/main/config/initializers/const.rb) helper
* Generate views, set mailer sender in credentials and add flash to layout
* Generate sample pages and protect ArticlesController using ApplicationUserController
* Sign in on development helper to sign in by GET request on staging and local
* Add controller and sytem test for signup
* -Enable TurboDeviseController- Turbo now works with Devise

and that all we do in `template.rb`

# API JWT Auth

For API Auth we will use https://github.com/waiting-for-dev/devise-jwt
and `template-for-api.rb`

```
rails app:template LOCATION=~/web-tips/devise_gem_tips/template-for-api.rb
```

Terminology:
* header: this can be used in native requests from mobile app for example
  `Authorization: Bearer my-jwt-token` so devise can determine current user.
* cookie: this is used inside browsers and also mobile apps can set in webview
  `CookieManager.getInstance().setCookie(BASE_URL, "oauth_token=${authToken}");`
  it has a limit of 4KB and it is just a plain string that server can read.
  Headers are used to set a cookie for example `curl -H "cookie:
  _gofordesi_webapp_session=asdasdasd"`

Note that inside mobile apps we need both authentications: for API and for
Webview.

Steps to enable authentication with jwt:

* Install devise-jwt
* Add devise_jwt_secret_key to credentials
* Configure devise config and User model
* Create JwtDenylist model and add `jwt_authenticatable` to User
* Show JWT token

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
* on a POST we need to skip verify csrf token

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

