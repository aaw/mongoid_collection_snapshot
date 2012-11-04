require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'

Mongoid.configure do |config|
  config.connect_to("mongoid_collection_snapshot_test")
end

require File.expand_path("../../lib/mongoid_collection_snapshot", __FILE__)
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

RSpec.configure do |c|
  c.before(:each) do
    Mongoid.purge!
  end
  c.after(:all) do
    Mongoid.default_session.drop
  end
end

