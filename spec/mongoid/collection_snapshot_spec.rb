require 'spec_helper'

module Mongoid
  describe CollectionSnapshot do
    it 'has a version' do
      expect(Mongoid::CollectionSnapshot::VERSION).not_to be_nil
    end

    context 'creating a basic snapshot' do
      let!(:andy_warhol) { Artist.create!(name: 'Andy Warhol') }
      let!(:damien_hirst) { Artist.create!(name: 'Damien Hirst') }
      let!(:flowers) { Artwork.create!(name: 'Flowers', artist: andy_warhol, price: 3_000_000) }
      let!(:guns) { Artwork.create!(name: 'Guns', artist: andy_warhol, price: 1_000_000) }
      let!(:vinblastine) { Artwork.create!(name: 'Vinblastine', artist: damien_hirst, price: 1_500_000) }

      it 'returns nil if no snapshot has been created' do
        expect(AverageArtistPrice.latest).to be_nil
      end

      it 'runs the build method on creation' do
        snapshot = AverageArtistPrice.create
        expect(snapshot.average_price('Andy Warhol')).to eq(2_000_000)
        expect(snapshot.average_price('Damien Hirst')).to eq(1_500_000)
      end

      it 'returns the most recent snapshot through the latest methods' do
        first = AverageArtistPrice.create
        expect(first).to eq(AverageArtistPrice.latest)
        # "latest" only works up to a resolution of 1 second since it relies on Mongoid::Timestamp. But this
        # module is meant to snapshot long-running collection creation, so if you need a resolution of less
        # than a second for "latest" then you're probably using the wrong gem. In tests, sleeping for a second
        # makes sure we get what we expect.
        Timecop.travel(1.second.from_now)
        second = AverageArtistPrice.create
        expect(AverageArtistPrice.latest).to eq(second)
        Timecop.travel(1.second.from_now)
        third = AverageArtistPrice.create
        expect(AverageArtistPrice.latest).to eq(third)
      end

      it 'maintains at most two of the latest snapshots to support its calculations' do
        AverageArtistPrice.create
        10.times do
          AverageArtistPrice.create
          expect(AverageArtistPrice.count).to eq(2)
        end
      end

      context '#documents' do
        it 'provides access to a Mongoid collection' do
          snapshot = AverageArtistPrice.create
          expect(snapshot.documents.count).to eq 2
          document = snapshot.documents.where(artist: andy_warhol).first
          expect(document.artist).to eq andy_warhol
          expect(document.count).to eq 2
          expect(document.sum).to eq 4_000_000
        end

        it 'only creates one global class reference' do
          3.times do
            index = AverageArtistPrice.create
            2.times { expect(index.documents.count).to eq 2 }
          end
          expect(AverageArtistPrice.document_classes.count).to be >= 3
        end
      end
    end

    context 'creating a snapshot containing multiple collections' do
      it 'populates several collections and allows them to be queried' do
        expect(MultiCollectionSnapshot.latest).to be_nil
        10.times { MultiCollectionSnapshot.create }
        expect(MultiCollectionSnapshot.latest.names).to eq('foo!bar!baz!')
      end

      it 'safely cleans up all collections used by the snapshot' do
        # Create some collections with names close to the snapshots we'll create
        if Mongoid::Compatibility::Version.mongoid5?
          Mongoid.default_client["#{MultiCollectionSnapshot.collection.name}.do.not_delete"].insert_one('a' => 1)
          Mongoid.default_client["#{MultiCollectionSnapshot.collection.name}.snapshorty"].insert_one('a' => 1)
          Mongoid.default_client["#{MultiCollectionSnapshot.collection.name}.hello.1"].insert_one('a' => 1)
        else
          Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.do.not_delete"].insert('a' => 1)
          Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.snapshorty"].insert('a' => 1)
          Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.hello.1"].insert('a' => 1)
        end

        MultiCollectionSnapshot.create
        collections = Mongoid::Compatibility::Version.mongoid5? ? Mongoid.default_client.database.collections : Mongoid.default_session.collections
        before_create = collections.map(&:name)
        expect(before_create.length).to be > 0

        Timecop.travel(1.second.from_now)
        MultiCollectionSnapshot.create
        collections = Mongoid::Compatibility::Version.mongoid5? ? Mongoid.default_client.database.collections : Mongoid.default_session.collections
        after_create = collections.map(&:name)
        collections_created = (after_create - before_create).sort
        expect(collections_created.length).to eq(3)

        MultiCollectionSnapshot.latest.destroy
        collections = Mongoid::Compatibility::Version.mongoid5? ? Mongoid.default_client.database.collections : Mongoid.default_session.collections
        after_destroy = collections.map(&:name)
        collections_destroyed = (after_create - after_destroy).sort
        expect(collections_created).to eq(collections_destroyed)
      end
    end

    context 'with a custom snapshot connection' do
      around(:each) do |example|
        if Mongoid::Compatibility::Version.mongoid5?
          CustomConnectionSnapshot.snapshot_session.database.drop
        else
          CustomConnectionSnapshot.snapshot_session.drop
        end
        example.run
        if Mongoid::Compatibility::Version.mongoid5?
          CustomConnectionSnapshot.snapshot_session.database.drop
        else
          CustomConnectionSnapshot.snapshot_session.drop
        end
      end

      it 'builds snapshot in custom database' do
        snapshot = CustomConnectionSnapshot.create
        [
          "#{CustomConnectionSnapshot.collection.name}.foo.#{snapshot.slug}",
          "#{CustomConnectionSnapshot.collection.name}.#{snapshot.slug}"
        ].each do |collection_name|
          session = Mongoid::Compatibility::Version.mongoid5? ? Mongoid.default_client : Mongoid.default_session
          expect(session[collection_name].find.count).to eq(0)
          expect(CustomConnectionSnapshot.snapshot_session[collection_name].find.count).to eq(1)
        end
      end

      context '#documents' do
        it 'uses the custom session' do
          if Mongoid::Compatibility::Version.mongoid5?
            expect(CustomConnectionSnapshot.new.documents.mongo_client).to eq CustomConnectionSnapshot.snapshot_session
          else
            expect(CustomConnectionSnapshot.new.documents.mongo_session).to eq CustomConnectionSnapshot.snapshot_session
          end
        end
        it 'provides access to a Mongoid collection' do
          snapshot = CustomConnectionSnapshot.create
          expect(snapshot.collection_snapshot.find.count).to eq 1
          expect(snapshot.documents.count).to eq 1
        end
      end
    end
  end
end
