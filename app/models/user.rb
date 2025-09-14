class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 1, maximum: 100 }

  has_many :sleep_records, dependent: :destroy
end
