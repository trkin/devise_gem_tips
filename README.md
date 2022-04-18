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
