# rubocop:disable Layout/HeredocIndentation
run %( git add . && git commit -m "rails new #{`echo ${PWD##*/}`}" )

run <<BASH
bundle add devise
rails generate devise:install
git add . && git commit -m "rails g devise:install"
git add . && git commit -am"bundle add devise"

rails g devise user
rails db:migrate
git add . && git commit -m "rails g devise user"

rails g devise:views
git add . && git commit -m "rails g devise:views"

EDITOR='echo "mailer_sender: My Company <support@example.com>" >> ' rails credentials:edit

sed -i "" -e '/mailer_sender/c\\
  config.mailer_sender = Rails.application.credentials.mailer_sender
' config/initializers/devise.rb

sed -i "" -e '/default from/c\\
  default from: Rails.application.credentials.mailer_sender
' app/mailers/application_mailer.rb

sed -i "" -e '/yield/i\\
    <p data-test="notice" class="notice"><%= notice %></p>\\
    <p data-test="alert" class="alert"><%= alert %></p>\\
    <%= link_to "Root", root_path %>\\
    <%= link_to "Articles", articles_path %>\\
    <% if current_user.present? %>\\
      <span data-test="current-user-email""><%= current_user.email %></span<>\\
      <%= button_to "Sign out", destroy_user_session_path, method: :delete, form_class: "d-inline" %>\\
    <% else %>\\
      <%= link_to "Login", new_user_session_path %>\\
    <% end %>\\
' app/views/layouts/application.html.erb

sed -i "" -e '/^  end/i\\
    config.action_mailer.default_url_options = {host: "localhost", port: 3000}
' config/application.rb

git add . && git commit -m "Set mailer_sender and add flash"
BASH

file 'config/initializers/const.rb', <<'RUBY', force: true
# https://github.com/duleorlovic/rails_helpers_and_const/blob/main/config/initializers/const.rb

# For Rails::Server::Options.new.parse!(ARGV)[:Port] to work in c and sidekiq
require "rails/commands" # we need this to sidekiq
require "rails/commands/server/server_command" # we need this for rails c or rails g migration
# there is an exception: uninitialized constant Rails::Server (NameError)
# I tried with Rack::Server.new.options[:Port] but it always returns 9292

module Const
  def self.common # rubocop:todo Metrics/MethodLength
    hash_or_error_if_key_does_not_exists(
      name: 'MyApp',
      # short_name is also use in config/sidekiq.yml and config/application.rb
      short_name: 'myapp',
      # default_url is required for links in email body or in links in controller
      # when url host is not available (for example rails console)
      # look below how default_url is used
      default_url: {
        host: if Rails.env.production?
                'www.myapp.com'
              elsif Rails.env.development?
                'localhost'
              else
                '127.0.0.1'
              end,
        port: (Rails.env.development? ? Rails::Server::Options.new.parse!(ARGV)[:Port] : nil),
        protocol: Rails.env.production? ? 'https' : 'http',
      },
    )
  end

  def self.hash_or_error_if_key_does_not_exists(hash)
    # https://stackoverflow.com/questions/30528699/why-isnt-an-exception-thrown-when-the-hash-value-doesnt-exist
    # raise if key does not exists hash[:non_exists] or hash.values_at[:non_exists]
    hash.default_proc = ->(_h, k) { raise KeyError, "#{k} not found!" }
    # raise when value not exists hash.key 'non_exists'
    def hash.key(value)
      k = super
      raise KeyError, "#{value} not found!" unless k

      k
    end
    hash
  end

  # https://stackoverflow.com/a/21249623/287166
  class ConstRailtie < Rails::Railtie
    link = Const.common[:default_url].symbolize_keys
    # for link urls in emails
    config.action_mailer.default_url_options = link
    # Set host for rails console:
    config.after_initialize do
      # image upload does not work since port can not be determined, so I will
      # skip setting default_url_options
      # Rails.application.routes.default_url_options[:host] = link[:host]
      Rails.application.routes.default_url_options = link
    end
    # for asset-url or img_tag in emails
    config.action_mailer.asset_host = if link[:port]
                                        "http://#{link[:host]}:#{link[:port]}"
                                      else
                                        "https://#{link[:host]}"
                                      end
    config.active_job.queue_name_prefix = Const.common[:short_name]
  end
end
RUBY

run <<BASH
rails g controller pages index
rails g scaffold articles title body:text
rails db:migrate
sed -i "" -e '/root "articles#index"/c\\
  root "pages#index"
' config/routes.rb
git add . && git commit -m "Add controller pages and scaffold articles"


cat > app/controllers/application_user_controller.rb << HERE_DOC
class ApplicationUserController < ApplicationController
  before_action :authenticate_user!
end
HERE_DOC

sed -i "" -e '/class ArticlesController/c\\
  class ArticlesController < ApplicationUserController
' app/controllers/articles_controller.rb
BASH

# Turbo and devise
# https://github.com/rails/thor/blob/master/lib/thor/actions/inject_into_file.rb
#
insert_into_file 'config/initializers/devise.rb', <<-RUBY, before: 'Devise.setup'
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
RUBY

run <<BASH
sed -i "" -e '/parent_controller/c\\
  config.parent_controller = "TurboDeviseController"
' config/initializers/devise.rb

sed -i "" -e '/config.warden do/i\\
  config.warden do |manager|\\
    manager.failure_app = TurboFailureApp\\
  end
' config/initializers/devise.rb

sed -i "" -e '/config.navigational_formats/a\\
  config.navigational_formats = ["*/*", :html, :turbo_stream]
' config/initializers/devise.rb

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

git add . && git commit -am"Add TurboDeviseController"
BASH

insert_into_file 'app/views/devise/sessions/new.html.erb', <<ERB, before: '<%= form_for'
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
ERB

insert_into_file 'app/controllers/pages_controller.rb', <<ERB, before: /^end/
  def sign_in_development
    render plain: "only_development" and return unless Rails.env.development?

    user = User.find params[:id]
    sign_in :user, user, bypass: true
    redirect_to params[:redirect_to] || root_path
  end
ERB

run <<BASH
sed -i "" -e '/get .pages.index/a\\
  get "sign-in-development/:id", to: "pages#sign_in_development", as: :sign_in_development
' config/routes.rb

git add . && git commit -am"Add sign_in_development_path"
BASH

# Add tests
file 'test/controllers/pages_controller_test.rb', <<-RUBY, force: true
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_path
    assert_response :success
  end

  test "sign_in_development" do
    get sign_in_development_path users(:user).id
    assert_equal "only_development", response.body
  end
end
RUBY

create_file 'test/controllers/application_user_controller_test.rb', <<-RUBY
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
RUBY

insert_into_file 'test/controllers/articles_controller_test.rb', <<-RUBY, after: "articles(:one)\n"
    sign_in users(:user)
RUBY

insert_into_file 'test/system/articles_test.rb', <<-RUBY, after: "articles(:one)\n"
    sign_in users(:user)
RUBY

empty_directory "test/a"
create_file "test/a/assert_flash_message.rb", <<-RUBY
# https://github.com/duleorlovic/minitest_rails/blob/main/test/a/assert_flash_message.rb
class ActionDispatch::IntegrationTest
  # assert_flash_message
  def assert_alert_message(text)
    assert_select '[data-test=alert]', text
  end

  def assert_notice_message(text)
    assert_select '[data-test=notice]', text
  end
end

class ActionDispatch::SystemTestCase
  def assert_alert_message(text)
    assert_selector '[data-test=alert]', text: text
  end

  def assert_notice_message(text)
    assert_selector '[data-test=notice]', text: text
  end
end
RUBY

insert_into_file "test/test_helper.rb", <<-RUBY, before: "class ActiveSupport"
Dir[Rails.root.join('test/a/**/*.rb')].sort.each { |f| require f }

RUBY

insert_into_file "test/test_helper.rb", <<-RUBY, before: "  # Add more helper methods"
  # devise method: sign_in user
  include Devise::Test::IntegrationHelpers

RUBY

create_file "test/fixtures/users.yml", <<-RUBY, force: true
DEFAULTS: &DEFAULTS
  email: $LABEL@email.com
  encrypted_password: <%= User.new.send(:password_digest, 'password') %>
  # confirmed_at: <%= Time.zone.now %>

user:
  <<: *DEFAULTS
RUBY

create_file "test/system/devise_log_in_and_reset_password_test.rb", <<-RUBY
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
    assert_selector '[data-test=current-user-email]', text: user.email
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
      /(http:\\S*)".*>Change my password/
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
RUBY

create_file "test/system/sign_up_test.rb", <<-RUBY
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
RUBY

create_file "test/application_system_test_case.rb", <<-RUBY, force: true
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  # you can use bye bug, but it will stop rails so you can not navigate to other
  # pages or make another requests in chrome while testing
  def pause
    $stderr.write('Press CTRL+j or ENTER to continue') && $stdin.gets
  end

end
RUBY

run <<BASH
git add . && git commit -am"Add test files"
BASH
# rubocop:enable Layout/HeredocIndentation
