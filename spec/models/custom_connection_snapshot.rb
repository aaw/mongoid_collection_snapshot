class CustomConnectionSnapshot
  include Mongoid::CollectionSnapshot

  def self.snapshot_session
    @@snapshot_session ||= Moped::Session.new(['127.0.0.1:27017']).tap do |session|
      session.use :snapshot_test
    end
  end

  def snapshot_session
    self.class.snapshot_session
  end

  def build
    collection_snapshot.insert('name' => 'foo')
    collection_snapshot('foo').insert({'name' => 'bar'})
  end
end
