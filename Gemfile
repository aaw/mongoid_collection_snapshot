source 'http://rubygems.org'

gemspec

case version = ENV['MONGOID_VERSION'] || '~> 5.0'
when /5/
  gem 'mongoid', '~> 5.0'
  gem 'mongoid-slug', github: 'dblock/mongoid-slug', branch: 'mongoid-5'
when /4/
  gem 'mongoid', '~> 4.0'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

group :development, :test do
  gem 'rspec', '~> 3.1'
  gem 'rake'
  gem 'timecop'
end
