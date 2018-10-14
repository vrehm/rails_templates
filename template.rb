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
gem 'semantic-ui-rails'

gem_group :development, :test do
  gem 'dotenv-rails'
  gem 'faker'
  gem 'pry-rails'
  gem 'rspec-rails', '~> 3.7'
  gem 'pry-bybug'
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

##############################
## APPLYING CUSTOM FILES
##############################
create_file 'Procfile' do
  %{release: bundle exec rails db:migrate
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
}
end

after_bundle do
  rails_command 'g semantic:install'
  rails_command 'db:migrate'
  git add: '.'
  git commit: "-m 'Initial commit'"
end

after_bundle do
end
