require 'spec_helper'

module Mongoid
  describe CollectionSnapshot do

    it "has a version" do
      expect(Mongoid::CollectionSnapshot::VERSION).not_to be_nil
    end

    context "creating a basic snapshot" do

      let!(:flowers)     { Artwork.create(:name => 'Flowers', :artist => 'Andy Warhol', :price => 3000000) }
      let!(:guns)        { Artwork.create(:name => 'Guns', :artist => 'Andy Warhol', :price => 1000000) }
      let!(:vinblastine) { Artwork.create(:name => 'Vinblastine', :artist => 'Damien Hirst', :price => 1500000) }

      it "returns nil if no snapshot has been created" do
        expect(AverageArtistPrice.latest).to be_nil
      end

      it "runs the build method on creation" do
        snapshot = AverageArtistPrice.create
        expect(snapshot.average_price('Andy Warhol')).to eq(2000000)
        expect(snapshot.average_price('Damien Hirst')).to eq(1500000)
      end

      it "returns the most recent snapshot through the latest methods" do
        first = AverageArtistPrice.create
        expect(first).to eq(AverageArtistPrice.latest)
        # "latest" only works up to a resolution of 1 second since it relies on Mongoid::Timestamp. But this
        # module is meant to snapshot long-running collection creation, so if you need a resolution of less
        # than a second for "latest" then you're probably using the wrong gem. In tests, sleeping for a second
        # makes sure we get what we expect.
        sleep(1)
        second = AverageArtistPrice.create
        expect(AverageArtistPrice.latest).to eq(second)
        sleep(1)
        third = AverageArtistPrice.create
        expect(AverageArtistPrice.latest).to eq(third)
      end

      it "should only maintain at most two of the latest snapshots to support its calculations" do
        AverageArtistPrice.create
        10.times do
          AverageArtistPrice.create
          expect(AverageArtistPrice.count).to eq(2)
        end
      end

    end

    context "creating a snapshot containing multiple collections" do

      it "populates several collections and allows them to be queried" do
        expect(MultiCollectionSnapshot.latest).to be_nil
        10.times { MultiCollectionSnapshot.create }
        expect(MultiCollectionSnapshot.latest.get_names).to eq("foo!bar!baz!")
      end

      it "safely cleans up all collections used by the snapshot" do
        # Create some collections with names close to the snapshots we'll create
        Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.do.not_delete"].insert({'a' => 1})
        Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.snapshorty"].insert({'a' => 1})
        Mongoid.default_session["#{MultiCollectionSnapshot.collection.name}.hello.1"].insert({'a' => 1})

        MultiCollectionSnapshot.create
        before_create = Mongoid.default_session.collections.map{ |c| c.name }
        expect(before_create.length).to be > 0

        sleep(1)
        MultiCollectionSnapshot.create
        after_create = Mongoid.default_session.collections.map{ |c| c.name }
        collections_created = (after_create - before_create).sort
        expect(collections_created.length).to eq(3)

        MultiCollectionSnapshot.latest.destroy
        after_destroy = Mongoid.default_session.collections.map{ |c| c.name }
        collections_destroyed = (after_create - after_destroy).sort
        expect(collections_created).to eq(collections_destroyed)
      end

    end

    context "with a custom snapshot connection" do

      around(:each) do |example|
        CustomConnectionSnapshot.snapshot_session.drop
        example.run
        CustomConnectionSnapshot.snapshot_session.drop
      end

      it "builds snapshot in custom database" do
        snapshot = CustomConnectionSnapshot.create
        [
          "#{CustomConnectionSnapshot.collection.name}.foo.#{snapshot.slug}",
          "#{CustomConnectionSnapshot.collection.name}.#{snapshot.slug}"
        ].each do |collection_name|
          expect(Mongoid.default_session[collection_name].find.count).to eq(0)
          expect(CustomConnectionSnapshot.snapshot_session[collection_name].find.count).to eq(1)
        end
      end

    end

  end
end
