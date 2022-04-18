# Deise gem basics

Devise gem https://github.com/heartcombo/devise
Start with

```
cat >> Gemfile <<HERE_DOC

# user authentication
gem 'devise'
HERE_DOC

bundle
rails generate devise:install
git add . && git commit -m "rails g devise:install"
```

If you do not have users table you can generate with

```
rails g devise User
last_migration
# add if you need:
# t.string :name, null: false, default: ''
# t.string :locale, null: false, default: ''
# t.boolean :superadmin, null: false, default: false
# uncomment Trackable and Confirmable and add_index
rake db:migrate
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
    <p class="notice"><%= notice %></p>\
    <p class="alert"><%= alert %></p>
' app/views/layouts/application.html.erb 

git add . && git commit -m "Set mailer_sender and add flash"
```

Generate sample pages

```
rails g controller pages index
rails g scaffold articles title body:textk
sed -i "" -e '/root/s\
  root "articles#index"
' config/routes.rb 


git add . && git commit -m "Add controller pages and scaffold articles"
```

