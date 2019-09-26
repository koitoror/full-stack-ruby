class Post < ApplicationRecord
  has_many :comments
  validates_presence_of :title, presence: true
end
