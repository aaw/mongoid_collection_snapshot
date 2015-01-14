class MultiCollectionSnapshot
  include Mongoid::CollectionSnapshot

  document('foo') do
    field :name, type: String
    field :count, type: Integer
  end

  document('bar') do
    field :name, type: String
    field :number, type: Integer
  end

  document('baz') do
    field :name, type: String
    field :digit, type: Integer
  end

  def build
    collection_snapshot('foo').insert('name' => 'foo!', count: 1)
    collection_snapshot('bar').insert('name' => 'bar!', number: 2)
    collection_snapshot('baz').insert('name' => 'baz!', digit: 3)
  end

  def names
    %w(foo bar baz).map { |x| collection_snapshot(x).find.first['name'] }.join('')
  end
end
