module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :connection_id

    def connect
      # We accept anonymous connections — individual channels (RoomChannel)
      # enforce room/membership validity. `connection_id` is just a random
      # per-socket identifier so we can deduplicate broadcasts.
      self.connection_id = SecureRandom.hex(8)
    end
  end
end
