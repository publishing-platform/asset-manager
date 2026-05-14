source "https://rubygems.org"

gem "rails", "~> 8.1.3"

gem "aws-sdk-core"
gem "aws-sdk-s3"
gem "carrierwave", "~> 3.0"
gem "pg", "~> 1.1"
gem "publishing_platform_app_config"
gem "publishing_platform_location"
gem "publishing_platform_sidekiq"
gem "sidekiq-unique-jobs", "< 8.1.1"
gem "state_machines-activerecord"
gem "tzinfo-data", platforms: %i[windows jruby]

gem "bootsnap", require: false

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "publishing_platform_rubocop"
  gem "publishing_platform_sso"
  gem "rspec-rails"
  gem "webmock", require: false
end

group :test do
  gem "rspec-sidekiq"
  gem "simplecov"
end
