run %Q{ git add . && git commit -m "rails new #{`echo ${PWD##*/}`}" }

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
    return unless Rails.env.development?

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

after_bundle do
  run "git add . && git commit -am'after_bundle commit'"
end

