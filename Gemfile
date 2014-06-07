source "http://rubygems.org"

case version = ENV['MONGOID_VERSION'] || '~> 3.1'
when /4/
  gem 'mongoid', github: 'mongoid/mongoid'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

gem "mongoid_slug"

group :development do
  gem "rspec", "~> 2.11.0"
  gem "jeweler", "~> 1.8.4"
end

