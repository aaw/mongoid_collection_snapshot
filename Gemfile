source 'http://rubygems.org'

case version = ENV['MONGOID_VERSION'] || '~> 4.0'
when /4/
  gem 'mongoid', '~> 4.0'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

gem 'mongoid_slug'

group :development, :test do
  gem 'rspec', '~> 3.1'
  gem 'rake'
end
