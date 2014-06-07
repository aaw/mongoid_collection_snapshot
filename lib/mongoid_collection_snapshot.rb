module Mongoid::CollectionSnapshot
  extend ActiveSupport::Concern

  included do
    require 'mongoid_slug'
    
    include Mongoid::Document
    include Mongoid::Timestamps::Created
    include Mongoid::Slug

    field :workspace_basename, default: 'snapshot'
    slug :workspace_basename
    
    field :max_collection_snapshot_instances, default: 2

    before_create :build
    after_create :ensure_at_most_two_instances_exist
    before_destroy :drop_snapshot_collections
  end

  module ClassMethods
    def latest
      order_by([[:created_at, :desc]]).first
    end
  end

  def collection_snapshot(name=nil)
    if name
      snapshot_session["#{self.collection.name}.#{name}.#{slug}"]
    else
      snapshot_session["#{self.collection.name}.#{slug}"]
    end
  end

  def drop_snapshot_collections
    snapshot_session.collections.each do |collection|
      collection.drop if collection.name =~ /^#{self.collection.name}\.([^\.]+\.)?#{slug}$/
    end
  end

  # Since we should always be using the latest instance of this class, this method is
  # called after each save - making sure only at most two instances exists should be
  # sufficient to ensure that this data can be rebuilt live without corrupting any
  # existing computations that might have a handle to the previous "latest" instance.
  def ensure_at_most_two_instances_exist
    all_instances = self.class.order_by([[:created_at, :desc]]).to_a
    if all_instances.length > self.max_collection_snapshot_instances
      all_instances[self.max_collection_snapshot_instances..-1].each { |instance| instance.destroy }
    end
  end

  # Override to supply custom database connection for snapshots
  def snapshot_session
    Mongoid.default_session
  end
  
end
