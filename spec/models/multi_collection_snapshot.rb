class MultiCollectionSnapshot
  include Mongoid::CollectionSnapshot
  
  def build
    collection_snapshot('foo').insert({'name' => 'foo!'})
    collection_snapshot('bar').insert({'name' => 'bar!'})
    collection_snapshot('baz').insert({'name' => 'baz!'})
  end

  def get_names
    ['foo', 'bar', 'baz'].map{ |x| collection_snapshot(x).find.first['name'] }.join('')
  end

end
