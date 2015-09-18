Mongoid Collection Snapshot
===========================

Easy maintenance of collections of processed data in MongoDB with Mongoid 3, 4 and 5.

[![Build Status](https://travis-ci.org/aaw/mongoid_collection_snapshot.svg)](https://travis-ci.org/aaw/mongoid_collection_snapshot)

Quick example:
--------------

Suppose that you have a Mongoid model called `Artwork`, stored in a MongoDB collection called `artworks` and the underlying documents look something like:

    { name: 'Flowers', artist: 'Andy Warhol', price: 3000000 }

From time to time, your system runs a map/reduce job to compute the average price of each artist's works, resulting in a collection called `artist_average_price` that contains documents that look like:

    { _id: { artist: 'Andy Warhol' }, value: { price: 1500000 } }

If your system wants to maintain and use this average price data, it has to do so at the level of raw MongoDB operations, since map/reduce result documents don't map well to models in Mongoid.
Furthermore, even though map/reduce jobs can take some time to run, you probably want the entire `artist_average_price` collection populated atomically from the point of view of your system, since otherwise you don't ever know the state of the data in the collection - you could access it in the middle of a map/reduce and get partial, incorrect results.

A mongoid_collection_snapshot solves this problem by providing an atomic view of collections of data like map/reduce results that live outside of Mongoid.

In the example above, we'd set up our average artist price collection like:

``` ruby
class AverageArtistPrice
  include Mongoid::CollectionSnapshot

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
      collection_snapshot.insert_one(
        artist_id: doc['_id']['artist_id'],
        count: doc['value']['count'],
        sum: doc['value']['sum']
      )
    end
  end
end

```

Now, if you want to schedule a recomputation, just call `AverageArtistPrice.create`. You can define other methods on collection snapshots.

```ruby
class AverageArtistPrice
  ...

  def average_price(artist_name)
    artist = Artist.where(name: artist_name).first
    doc = collection_snapshot.where(artist_id: artist.id).first
    doc['sum'] / doc['count']
  end
end
```

The latest snapshot is always available as `AverageArtistPrice.latest`, so you can write code like:

```ruby
warhol_expected_price = AverageArtistPrice.latest.average_price('Andy Warhol')
```

And always be sure that you'll never be looking at partial results. The only thing you need to do to hook into mongoid_collection_snapshot is implement the method `build`, which populates the collection snapshot and any indexes you need.

By default, mongoid_collection_snapshot maintains the most recent two snapshots computed any given time.

Query Snapshot Data with Mongoid
--------------------------------

You can do better than the average price example above and define first-class models for your collection snapshot data, then access them as any other Mongoid collection via collection snapshot's `.documents` method.

```ruby
class AverageArtistPrice
  document do
    belongs_to :artist, inverse_of: nil
    field :sum, type: Integer
    field :count, type: Integer
  end

  def average_price(artist_name)
    artist = Artist.where(name: artist_name).first
    doc = documents.where(artist: artist).first
    doc.sum / doc.count
  end
end
```

Another example iterates through all latest artist price averages.

```ruby
AverageArtistPrice.latest.documents.each do |doc|
  puts "#{doc.artist.name}: #{doc.sum / doc.count}"
end
```

Multi-collection snapshots
--------------------------

You can maintain multiple collections atomically within the same snapshot by passing unique collection identifiers to `collection_snaphot` when you call it in your build or query methods:

``` ruby
class ArtistStats
  include Mongoid::CollectionSnapshot

  def build
    # ...
    # define map/reduce for average and max aggregations
    # ...
    Mongoid.default_session.command('mapreduce' => 'artworks', map: map_avg, reduce: reduce_avg, out: collection_snapshot('average'))
    Mongoid.default_session.command('mapreduce' => 'artworks', map: map_max, reduce: reduce_max, out: collection_snapshot('max'))
  end

  def average_price(artist)
    doc = collection_snapshot('average').find('_id.artist' => artist).first
    doc['value']['sum'] / doc['value']['count']
  end

  def max_price(artist)
    doc = collection_snapshot('max').find('_id.artist' => artist).first
    doc['value']['max']
  end
end
```

Specify the name of the collection to define first class Mongoid models.

```ruby
class ArtistStats
  document('average') do
    field :value, type: Hash
  end

  document('max') do
    field :value, type: Hash
  end
end
```

Access these by name.

```ruby
ArtistStats.latest.documents('average')
ArtistStats.latest.documents('max')
```

If fields across multiple collection snapshots are identical, a single default `document` is sufficient.

```ruby
class ArtistStats
  document do
    field :value, type: Hash
  end
end
```

Custom database connections
---------------------------

Your class can specify a custom database for storage of collection snapshots by overriding the `snapshot_session` instance method. In this example, we memoize the connection at the class level to avoid creating many separate connection instances.

```ruby
class ArtistStats
  include Mongoid::CollectionSnapshot

  def build
    # ...
  end

  def snapshot_session
    self.class.snapshot_session
  end

  def self.snapshot_session
    @@snapshot_session ||= Mongo::Client.new('mongodb://localhost:27017').tap do |c|
      c.use :alternate_db
    end
  end
end
```

Another common way of configuring this is through mongoid.yml.

```yaml
development:
  sessions:
    default:
      database: dev_data
    imports:
      database: dev_imports
```

```ruby
  def snapshot_session
    Mongoid.session('imports')
  end
```

License
=======

MIT License, see [LICENSE.txt](https://github.com/aaw/mongoid_collection_snapshot/blob/master/LICENSE.txt) for details.
