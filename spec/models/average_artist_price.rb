class AverageArtistPrice
  include Mongoid::CollectionSnapshot

  document do
    belongs_to :artist, inverse_of: nil
    field :sum, type: Integer
    field :count, type: Integer
  end

  def build
    map = <<-EOS
      function() {
        emit({ artist_id: this['artist_id']}, { count: 1, sum: this['price'] })
      }
    EOS

    reduce = <<-EOS
      function(key, values) {
        var sum = 0;
        var count = 0;
        values.forEach(function(value) {
          sum += value['sum'];
          count += value['count'];
        });
        return({ count: count, sum: sum });
      }
    EOS

    Artwork.map_reduce(map, reduce).out(inline: 1).each do |doc|
      if Mongoid::Compatibility::Version.mongoid5?
        collection_snapshot.insert_one(
          artist_id: doc['_id']['artist_id'],
          count: doc['value']['count'],
          sum: doc['value']['sum']
        )
      else
        collection_snapshot.insert(
          artist_id: doc['_id']['artist_id'],
          count: doc['value']['count'],
          sum: doc['value']['sum']
        )
      end
    end
  end

  def average_price(artist_name)
    artist = Artist.where(name: artist_name).first
    fail 'missing artist' unless artist
    doc = documents.where(artist: artist).first
    fail 'missing record' unless doc
    doc.sum / doc.count
  end
end
