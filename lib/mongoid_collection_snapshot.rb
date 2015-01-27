require 'mongoid_collection_snapshot/version'

module Mongoid
  module CollectionSnapshot
    extend ActiveSupport::Concern

    DEFAULT_COLLECTION_KEY_NAME = '*'

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

      cattr_accessor :document_blocks
      cattr_accessor :document_classes

      # Mongoid documents on this snapshot.
      def documents(name = nil)
        self.document_classes ||= {}
        class_name = "#{self.class.name}#{id}#{name}".underscore.camelize
        key = "#{class_name}-#{name || DEFAULT_COLLECTION_KEY_NAME}"
        self.document_classes[key] ||= begin
          document_block = document_blocks[name || DEFAULT_COLLECTION_KEY_NAME] if document_blocks
          collection_name = collection_snapshot(name).name
          klass = Class.new do
            include Mongoid::Document
            cattr_accessor :mongo_session
            instance_eval(&document_block) if document_block
            store_in collection: collection_name
          end
          klass.mongo_session = snapshot_session
          Object.const_set(class_name, klass)
          klass
        end
      end
    end

    module ClassMethods
      def latest
        order_by([[:created_at, :desc]]).first
      end

      def document(name = nil, &block)
        self.document_blocks ||= {}
        self.document_blocks[name || DEFAULT_COLLECTION_KEY_NAME] = block
      end
    end

    def collection_snapshot(name = nil)
      if name
        snapshot_session["#{collection.name}.#{name}.#{slug}"]
      else
        snapshot_session["#{collection.name}.#{slug}"]
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
      return unless all_instances.length > max_collection_snapshot_instances
      all_instances[max_collection_snapshot_instances..-1].each(&:destroy)
    end

    # Override to supply custom database connection for snapshots
    def snapshot_session
      Mongoid.default_session
    end
  end
end
