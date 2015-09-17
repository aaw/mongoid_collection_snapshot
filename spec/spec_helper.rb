require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'
require 'timecop'

Mongoid.configure do |config|
  config.connect_to('mongoid_collection_snapshot_test')
end

require File.expand_path('../../lib/mongoid_collection_snapshot', __FILE__)
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

require 'mongoid-compatibility'

RSpec.configure do |c|
  c.before(:all) do
    Mongoid.logger.level = Logger::INFO
    Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5?
  end
  c.before(:each) do
    Mongoid.purge!
  end
  c.after(:all) do
    if Mongoid::Compatibility::Version.mongoid5?
      Mongoid.default_client.database.drop
    else
      Mongoid.default_session.drop
    end
  end
end

RSpec.configure(&:raise_errors_for_deprecations!)
