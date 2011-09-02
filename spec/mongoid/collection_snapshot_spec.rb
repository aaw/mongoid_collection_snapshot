require 'spec_helper'

module Mongoid
  describe CollectionSnapshot do

    context "creating a snapshot" do
      
      let!(:flowers)     { Artwork.create(:name => 'Flowers', :artist => 'Andy Warhol', :price => 3000000) }
      let!(:guns)        { Artwork.create(:name => 'Guns', :artist => 'Andy Warhol', :price => 1000000) }
      let!(:vinblastine) { Artwork.create(:name => 'Vinblastine', :artist => 'Damien Hirst', :price => 1500000) }

      it "returns nil if no snapshot has been created" do
        AverageArtistPrice.latest.should be_nil
      end
      it "runs the build method on creation" do
        snapshot = AverageArtistPrice.create
        snapshot.average_price('Andy Warhol').should == 2000000
        snapshot.average_price('Damien Hirst').should == 1500000
      end
      it "returns the most recent snapshot through the latest methods" do
        first = AverageArtistPrice.create
        first.should == AverageArtistPrice.latest
        # "latest" only works up to a resolution of 1 second since it relies on Mongoid::Timestamp. But this
        # module is meant to snapshot long-running collection creation, so if you need a resolution of less
        # than a second for "latest" then you're probably using the wrong gem. In tests, sleeping for a second
        # makes sure we get what we expect.
        sleep(1)
        second = AverageArtistPrice.create
        AverageArtistPrice.latest.should == second
        sleep(1)
        third = AverageArtistPrice.create
        AverageArtistPrice.latest.should == third        
      end
      it "should only maintain at most two of the latest snapshots to support its calculations" do
        10.times do
          AverageArtistPrice.create
          AverageArtistPrice.count.should <= 2
        end
      end
    end

  end
end
