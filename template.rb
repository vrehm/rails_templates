#  ______      _ _       _____                    _       _
#  | ___ \    (_) |     |_   _|                  | |     | |
#  | |_/ /__ _ _| |___    | | ___ _ __ ___  _ __ | | __ _| |_ ___  ___
#  |    // _` | | / __|   | |/ _ \ '_ ` _ \| '_ \| |/ _` | __/ _ \/ __|
#  | |\ \ (_| | | \__ \   | |  __/ | | | | | |_) | | (_| | ||  __/\__ \
#  \_| \_\__,_|_|_|___/   \_/\___|_| |_| |_| .__/|_|\__,_|\__\___||___/
#                                          | |
#                                          |_|

APP_NAME = @app_name.titleize
RAILS_VERSION = File.read('Gemfile').scan(%r{(?<=gem 'rails', '~> ).*(?=')}).first

##############################
## INSTALL GEMS
##############################
gem 'sidekiq'
gem 'config'
gem 'devise'
gem 'premailer-rails'
gem 'semantic-ui-sass'

gem_group :development, :test do
  gem 'dotenv-rails'
  gem 'faker'
  gem 'pry-rails'
  gem 'rspec-rails', '~> 3.7'
  gem 'pry-byebug'
end

# Remove all coments and empty space fron the gemfile
gsub_file 'Gemfile', /(^#|^. #).*?\n+/, ''
gsub_file 'Gemfile', /^[\r\n]+/, "\n"

run 'bundle install'

application do
  %{config.generators.stylesheets = true
    config.generators.javascripts = true
    config.generators.helper      = true

    config.generators do |g|
      g.test_framework :rspec,
        fixtures:         true,
        view_specs:       false,
        helper_specs:     false,
        routing_specs:    false,
        controller_specs: true,
        request_specs:    true
    end
}
end

##############################
## CREATE FILE FOR ENV VARIABLES
##############################
create_file '.env'
append_to_file '.gitignore', ".env\n"

##############################
## GENERATING HOME CONTROLLER
##############################
if yes?('Generate home controller and root path?')
  generate :controller, 'home show'
  gsub_file 'config/routes.rb', "get 'home/show'", "root to: 'home#show'"
end

##############################
## ACCOUNT AND USER MODELS
##############################
generate_users = yes?('Generate a user-model?')
if generate_users
  generate_accounts = yes?('Generate an account-model (user belongs to account)?')

  if generate_accounts
    generate :model, 'account', 'name'
    generate :model, 'user', 'account:references', 'name', 'email'
  else
    generate :model, 'user', 'name', 'email'
  end
end

##############################
## SETUP DB
##############################
run 'rails db:create db:migrate'

after_bundle do
  run 'spring stop'
end

##############################
## APPLYING SIDEKIQ
##############################
application 'config.active_job.queue_adapter = :sidekiq'

create_file 'config/sidekiq.yml' do
%{---
:concurrency: 3
production:
  :concurrency: 10
:queues:
  - [high, 10]
  - [default, 5]
  - [low, 1]
}
end

create_file 'config/initializers/sidekiq.rb' do
%{if Rails.env.production?
  Sidekiq.configure_client do |config|
    config.redis = { url: "redis://#{ENV['REDIS_URL']}:6379" }
  end

  Sidekiq.configure_server do |config|
    config.redis = { url: "redis://#{ENV['REDIS_URL']}:6379" }
  end
end}
end

append_to_file 'README.md' do
%{
## Sidekiq

Read more at: https://github.com/mperham/sidekiq/wiki/Getting-Started

Start with:
```
sidekiq -C config/sidekiq.yml
```
}
end

##############################
## APPLYING RAILS_CONFIG
##############################
generate 'config:install'

append_to_file 'README.md' do
%{
## Rails Config

Config helps you easily manage environment specific settings in an easy and usable manner.
Read more at: https://github.com/railsconfig/config
}
end

##############################
## APPLYING RSPEC
##############################
remove_dir 'test'
generate 'rspec:install'

append_to_file 'README.md' do
%{
## Rspec

Read more at: https://github.com/rspec/rspec-rails
}
end

##############################
## APPLYING DEVISE
##############################
generate 'devise:install'
generate 'devise user'
generate 'devise:views users'

if generate_users
  in_root do
    migration = Dir.glob("db/migrate/*").max_by { |f| File.mtime(f) }
    gsub_file migration, 't.string :email', '# t.string :email'
  end
end

environment "config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }", env: 'development'
environment "config.action_mailer.delivery_method = :smtp", env: 'development'
environment "config.action_mailer.smtp_settings = { address: 'localhost', port: 1025 }", env: 'development'

append_to_file 'README.md' do
%{
## Devise

Read more at: https://github.com/plataformatec/devise
}
end

##############################
## APPLYING CUSTOM FILES
##############################
create_file 'Procfile' do
  %{web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
}
end

create_file 'config/routes.rb' do
  %{Rails.application.routes.draw do
  devise_for :users
  root to: 'home#show'
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
}
end

create_file 'app/views/home/show.html.erb' do
  %{<div class="ui fixed inverted menu">
  <div class="ui container">
    <a href="#" class="header item">
      <img class="logo" src="https://semantic-ui.com/examples/assets/images/logo.png">
      Project Name
    </a>
    <a href="#" class="item">Home</a>
    <div class="ui simple dropdown item">
      Dropdown <i class="dropdown icon"></i>
      <div class="menu">
        <a class="item" href="#">Link Item</a>
        <a class="item" href="#">Link Item</a>
        <div class="divider"></div>
        <div class="header">Header Item</div>
        <div class="item">
          <i class="dropdown icon"></i>
          Sub Menu
          <div class="menu">
            <a class="item" href="#">Link Item</a>
            <a class="item" href="#">Link Item</a>
          </div>
        </div>
        <a class="item" href="#">Link Item</a>
      </div>
    </div>
  </div>
</div>

<div class="ui main text container">
  <h1 class="ui header">Semantic UI Fixed Template</h1>
  <p>This is a basic fixed menu template using fixed size containers.</p>
  <p>A text container is used for the main container, which is useful for single column layouts</p>
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/media-paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
  <img class="wireframe" src="https://semantic-ui.com/examples/assets/images/wireframe/paragraph.png">
</div>

<div class="ui inverted vertical footer segment">
  <div class="ui center aligned container">
    <div class="ui stackable inverted divided grid">
      <div class="three wide column">
        <h4 class="ui inverted header">Group 1</h4>
        <div class="ui inverted link list">
          <a href="#" class="item">Link One</a>
          <a href="#" class="item">Link Two</a>
          <a href="#" class="item">Link Three</a>
          <a href="#" class="item">Link Four</a>
        </div>
      </div>
      <div class="three wide column">
        <h4 class="ui inverted header">Group 2</h4>
        <div class="ui inverted link list">
          <a href="#" class="item">Link One</a>
          <a href="#" class="item">Link Two</a>
          <a href="#" class="item">Link Three</a>
          <a href="#" class="item">Link Four</a>
        </div>
      </div>
      <div class="three wide column">
        <h4 class="ui inverted header">Group 3</h4>
        <div class="ui inverted link list">
          <a href="#" class="item">Link One</a>
          <a href="#" class="item">Link Two</a>
          <a href="#" class="item">Link Three</a>
          <a href="#" class="item">Link Four</a>
        </div>
      </div>
      <div class="seven wide column">
        <h4 class="ui inverted header">Footer Header</h4>
        <p>Extra space for a call to action inside the footer that could help re-engage users.</p>
      </div>
    </div>
    <div class="ui inverted section divider"></div>
    <img src="https://semantic-ui.com/examples/assets/images/logo.png" class="ui centered mini image">
    <div class="ui horizontal inverted small divided link list">
      <a class="item" href="#">Site Map</a>
      <a class="item" href="#">Contact Us</a>
      <a class="item" href="#">Terms and Conditions</a>
      <a class="item" href="#">Privacy Policy</a>
    </div>
  </div>
</div>

}
end

create_file 'app/assets/stylesheets/application.css.scss' do
  %{@import "semantic-ui";
}
end

create_file 'app/assets/javascripts/application.js' do
  %{// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require jquery
// Loads all Semantic javascripts
//= require semantic-ui
//= require_tree .
}
end

# create_file 'app/views/layouts/application.html.erb' do
#   %{<!DOCTYPE html>
# <html>
#   <head>
#     <!-- Standard Meta -->
#     <meta charset="utf-8" />
#     <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
#     <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">

#     <!-- Site Properties -->
#     <title><%= yield(:title) %></title>
#     <%= csrf_meta_tags %>
#     <%= csp_meta_tag %>

#     <%= stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track': 'reload' %>
#     <%= javascript_include_tag 'application', 'data-turbolinks-track': 'reload' %>
#   </head>

#   <body>
#     <%= yield %>
#   </body>
# </html>
# }
#end

after_bundle do
  rails_command 'db:migrate'
  git add: '.'
  git commit: "-m 'Initial commit'"
end

after_bundle do
  run "cd #{APP_NAME}"
  rails_command 'assets:precompile'
end
