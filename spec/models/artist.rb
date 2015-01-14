class Artist
  include Mongoid::Document

  field :name

  has_many :artworks
end
