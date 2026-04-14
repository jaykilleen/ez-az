class Counter < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }

  def self.increment_and_get(key_name)
    find_or_create_by!(key: key_name) { |c| c.value = 0 }
    where(key: key_name).update_all("value = value + 1")
    where(key: key_name).pick(:value)
  end
end
