# https://github.com/trkin/devise_gem_tips/blob/main/template.rb
# rubocop:disable Layout/HeredocIndentation

run(<<HERE_DOC) or exit 1
set -e # Any commands which fail will cause the shell script to exit immediately
set -x # Show command being executed

# Initial commit is not needed when using template on existing project, using as
# rails app:template LOCATION=~/web-tips/devise_gem_tips/template.rb
git add . && git commit -m "rails new #{`echo ${PWD##*/}`}"

bundle add devise
rails g devise:install
rails g devise:views

git add . && git commit -m "Add devise gem

bundle add devise
rails g devise:install
rails g devise:views"
HERE_DOC

# Generate default user model if you do not already have users table
run <<HERE_DOC
rails g devise user
rails db:create db:migrate
# edit last_migration to add name, locale, admin field
# admin can be used in as sign_in_development
# t.string :name, null: false, default: ''
# t.string :locale, null: false, default: ''
# t.boolean :admin, null: false, default: false
# uncomment Trackable and Confirmable and add_index
# vi app/models/user.rb # add :confirmable, :trackable
git add . && git commit -m "rails g devise user"
HERE_DOC

# Use Const helper
run <<'HERE_DOC'
curl https://raw.githubusercontent.com/duleorlovic/rails_helpers_and_const/main/config/initializers/const.rb > config/initializers/const.rb
HERE_DOC

# Generate views, set mailer sender in credentials and add flash to layout
run <<'HERE_DOC'
set -e -x # Any commands which fail will cause the shell script to exit immediately

sed -i "" -e '/mailer_sender/c\
  config.mailer_sender = Const.common[:mailer_sender]
' config/initializers/devise.rb

sed -i "" -e '/default from/c\
  default from: Const.common[:mailer_sender]
' app/mailers/application_mailer.rb

sed -i "" -e '/yield/i\
    <p data-test="notice" class="notice"><%= notice %></p>\
    <p data-test="alert" class="alert"><%= alert %></p>\
    <%= link_to "Root", root_path %>\
    <%= link_to "Articles", articles_path %>\
    <% if current_user.present? %>\
      <span data-test="current-user-email"><%= current_user.email %></span>\
      <%= button_to "Sign out", destroy_user_session_path, method: :delete, form_class: "d-inline" %>\
    <% else %>\
      <%= link_to "Login", new_user_session_path %>\
    <% end %>\
' app/views/layouts/application.html.erb

git add . && git commit -m "Set mailer_sender and add flash"
HERE_DOC

# Generate sample pages and protect ArticlesController using ApplicationUserController
run <<'HERE_DOC_RUN'
rails g controller pages index
rails g scaffold articles title body:text
rails db:migrate
sed -i "" -e '/root "articles#index"/c\
  root "pages#index"
' config/routes.rb
cat >> app/views/pages/index.html.erb << HERE_DOC
<div data-controller="hello">
  hello controller should be replaced with "Hello World!"
</div>
HERE_DOC

git add . && git commit -m "Add controller pages and scaffold articles"


cat > app/controllers/application_user_controller.rb << HERE_DOC
class ApplicationUserController < ApplicationController
  before_action :authenticate_user!
end
HERE_DOC

sed -i "" -e '/class ArticlesController/c\
  class ArticlesController < ApplicationUserController
' app/controllers/articles_controller.rb
HERE_DOC
HERE_DOC_RUN

# Sign in development helper
insert_into_file 'app/views/devise/sessions/new.html.erb', <<HERE_DOC, before: '<%= form_for'
<% if Rails.env.development? %>
  <small>
    Only on development
    <dl>
      <dt>users:</dt>
      <dd>
        <% User.order(:created_at).limit(5).each do |user| %>
          <%= link_to user.email, sign_in_development_path(user) %>
        <% end %>
      </dd>
    </dl>
  </small>
<% end %>
HERE_DOC

insert_into_file 'app/controllers/pages_controller.rb', <<HERE_DOC, before: /^end/
  def sign_in_development
    render plain: "only_development" and return unless Rails.env.development?

    user = User.find params[:id]
    sign_in :user, user, bypass: true
    redirect_to params[:redirect_to] || root_path
  end
HERE_DOC

run <<HERE_DOC
sed -i "" -e '/get .pages.index/a\
  get "sign-in-development/:id", to: "pages#sign_in_development", as: :sign_in_development
' config/routes.rb

git add . && git commit -am"Add sign_in_development_path"
HERE_DOC

# Add tests
run <<HERE_DOC_RUN

cat > test/controllers/pages_controller_test.rb <<'HERE_DOC'
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
    assert_select "[data-test-current-user-email]", count: 0
  end

  test "sign_in_development" do
    get sign_in_development_path users(:user).id
    assert_equal "only_development", response.body
  end

  test "devise sign_in method" do
    user = users(:user)
    sign_in user
    get root_path
    assert_select "[data-test='current-user-email']", user.email
  end

  test "log in" do
    user = users(:user)
    post user_session_path user: { email: user.email, password: "password" }
    follow_redirect!
    assert_notice_message "Signed in successfully."
    assert_current_user user
  end
end
HERE_DOC

cat > test/controllers/application_user_controller_test.rb <<'HERE_DOC'
require "test_helper"

class ApplicationUserControllerTest < ActionDispatch::IntegrationTest
  test "root" do
    get root_path
    assert_response :success
  end

  test "articles non logged in" do
    get articles_path
    assert_response :redirect
  end

  test "articles logged in" do
    sign_in users(:user)
    get articles_path
    assert_response :success
  end
end
HERE_DOC

sed -i "" -e '/articles(:one)/i\
    sign_in users(:user)
' test/controllers/articles_controller_test.rb

sed -i "" -e '/articles(:one)/i\
    sign_in users(:user)
' test/system/articles_test.rb

mkdir test/a
cat > test/a/assert_flash_message.rb << HERE_DOC
# https://github.com/trkin/rails_minitest/blob/main/test/a/assert_flash_message.rb
class ActionDispatch::IntegrationTest
  # assert_flash_message is not using data-test-alert="my message" but
  # data-test="alert" because we want to see how text differs if test fails
  def assert_alert_message(text)
    assert_select '[data-test="alert"]', text
  end

  def assert_notice_message(text)
    assert_select '[data-test="notice"]', text
  end

  def assert_current_user(user)
    assert_select '[data-test="current-user-email"]', user.email
  end
end

class ActionDispatch::SystemTestCase
  def assert_alert_message(text)
    assert_selector "[data-test='alert']", text: text
  end

  def assert_notice_message(text)
    assert_selector "[data-test='notice']", text: text
  end

  def assert_current_user(user)
    assert_selector "[data-test='current-user-email']", text: user.email
  end
end
HERE_DOC

sed -i "" -e '/class ActiveSupport/i\
Dir[Rails.root.join("test/a/**/*.rb")].sort.each { |f| require f }\

' test/test_helper.rb

sed -i "" -e '/  # Add more helper methods/i\
  # devise method: sign_in user\
  include Devise::Test::IntegrationHelpers\

' test/test_helper.rb

cat > test/fixtures/users.yml <<'HERE_DOC'
DEFAULTS: &DEFAULTS
  email: $LABEL@email.com
  encrypted_password: <%= User.new.send(:password_digest, 'password') %>
  # confirmed_at: <%= Time.zone.now %>

user:
  <<: *DEFAULTS
HERE_DOC

cat > "test/system/devise_log_in_and_reset_password_test.rb" <<HERE_DOC
require 'application_system_test_case'

class DeviseLogInResetPasswordTest < ApplicationSystemTestCase
  test 'log in' do
    user = users(:user)
    visit root_path
    click_on 'Login'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'wrong'
    click_on 'Log in'

    assert_alert_message 'Invalid Email or password.'

    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on 'Log in'

    assert_notice_message "Signed in successfully."
    assert_current_user user
  end

  test 'forgot password with email' do
    user = users(:user)
    visit root_path
    click_on 'Login'
    click_on "Forgot your password?"
    fill_in 'Email', with: user.email
    click_on 'Send me reset password instructions'

    assert_notice_message 'You will receive an email with instructions on how to reset your password in a few minutes.'
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    password_link = mail.body.encoded.match(
      /(http:\S*)".*>Change my password/
    )[1]
    visit password_link

    fill_in 'New password', with: 'new_pass'
    fill_in 'Confirm new password', with: 'new_pass'
    click_on 'Change my password'

    assert_notice_message "Your password has been changed successfully."

    user = User.find_by(email: user.email)
    assert user.valid_password? 'new_pass'
  end

  # test 'resend confirmation instructions' do
  #   user = users(:user)
  #   user.update! confirmed_at: nil

  #   visit root_path
  #   click_on 'Login'
  #   click_on "Didn't receive confirmation instructions?"
  #   fill_in 'Email', with: user.email
  #   click_on 'Resend confirmation instructions'

  #   assert_notice_message 'You will receive an email with instructions for how to confirm your email address in a few minutes.'
  #   mail = ActionMailer::Base.deliveries.last
  #   assert_equal [user.email], mail.to
  #   confirm_link = mail.body.encoded.match(
  #     /(http:\S*)".*>Confirm my account/
  #   )[1]
  #   visit confirm_link

  #   assert_notice_message 'Your email address has been successfully confirmed.'
  #   user.reload
  #   assert user.confirmed_at
  # end
end
HERE_DOC

cat > "test/system/sign_up_test.rb" <<HERE_DOC
require 'application_system_test_case'

class SignUpTest < ApplicationSystemTestCase
  test 'sign up' do
    visit root_path
    click_on 'Login'
    click_on "Sign up"
    fill_in 'Email', with: "new@email.com"
    fill_in 'Password', with: 'password'
    fill_in 'Password confirmation', with: 'password'
    click_on 'Sign up'
    assert_notice_message "Welcome! You have signed up successfully."
    user = User.find_by email: "new@email.com"
    assert user.valid_password? 'password'
  end
end
HERE_DOC

cat > "test/application_system_test_case.rb" <<'HERE_DOC'
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # you can use bye bug, but it will stop rails so you can not navigate to other
  # pages or make another requests in chrome while testing
  def pause
    $stderr.write('Press CTRL+j or ENTER to continue') && $stdin.gets
  end
end
HERE_DOC

git add . && git commit -am"Add test files for devise"
HERE_DOC

HERE_DOC_RUN

# rubocop:enable Layout/HeredocIndentation
