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
gem 'rails-ujs'
gem 'jquery-rails'

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

rails_command 'db:migrate db:seed'

##############################
## APPLYING CUSTOM FILES
##############################
create_file 'Procfile' do
  %{web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
}
end

run 'rm config/routes.rb'
create_file 'config/routes.rb' do
  %{Rails.application.routes.draw do
  devise_for :users
  root to: 'home#show'
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
}
end

run 'rm app/views/home/show.html.erb'
create_file 'app/views/home/show.html.erb' do
  %{<div class="ui raised very padded text container segment">
  <h2 class="ui header">Dogs Roles with Humans</h2>
  <p>Domestic dogs inherited complex behaviors, such as bite inhibition, from their wolf ancestors, which would have been pack hunters with complex body language. These sophisticated forms of social cognition and communication may account for their trainability, playfulness, and ability to fit into human households and social situations, and these attributes have given dogs a relationship with humans that has enabled them to become one of the most successful species on the planet today.</p>
  <p>The dogs' value to early human hunter-gatherers led to them quickly becoming ubiquitous across world cultures. Dogs perform many roles for people, such as hunting, herding, pulling loads, protection, assisting police and military, companionship, and, more recently, aiding handicapped individuals. This impact on human society has given them the nickname "man's best friend" in the Western world. In some cultures, however, dogs are also a source of meat.</p>
</div>
<div class="ui padded text container">
  <div class="ui icon message">
    <i class="notched circle loading icon"></i>
    <div class="content">
      <div class="header">
        Just one second
      </div>
      <p>We're fetching that content for you.</p>
    </div>
  </div>
</div>
}
end

run 'rm app/assets/stylesheets/application.css'
create_file 'app/assets/stylesheets/application.scss' do
  %{@import 'semantic-ui';
}
end

run 'rm app/assets/javascripts/application.js'
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

run 'rm app/views/layouts/application.html.erb'
create_file 'app/views/layouts/application.html.erb' do
  %{<!DOCTYPE html>
<html>
  <head>
    <!-- Standard Meta -->
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">

    <!-- Site Properties -->
    <title><%= Rails.application.class.parent_name %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <!-- Site CSS -->
    <%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
  </head>

  <body>
    <%= yield %>
    <!-- Site JS -->
    <%= javascript_include_tag 'application',
      'data-turbolinks-track': 'reload',
      'data-turbolinks-suppress-warning': 'true',
      'defer': 'true' %>
  </body>
</html>
}
end

after_bundle do
  rails_command 'generate devise:views users'
  rails_command 'db:migrate db:seed'
  rails_command 'assets:precompile'
  git add: '.'
  git commit: "-m 'Initial commit'"
end
