source "https://rubygems.org"

gem "rails", "~> 8.1.3"

gem "pg", "~> 1.1"
gem "publishing_platform_app_config"
gem "tzinfo-data", platforms: %i[windows jruby]

gem "bootsnap", require: false

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "publishing_platform_rubocop"
  gem "publishing_platform_sso"
  gem "rspec-rails"
  gem "webmock", require: false
end

group :test do
  gem "simplecov"
end
