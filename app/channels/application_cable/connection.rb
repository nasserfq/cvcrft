module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # Devise keeps the user in the Warden session, which the socket shares.
    def connect
      self.current_user = env["warden"].user || reject_unauthorized_connection
    end
  end
end
