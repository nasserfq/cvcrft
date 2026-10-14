module Coach
  class ChatChannel < ApplicationCable::Channel
    def subscribed
      chat = Coach::Chat.find_by(id: params[:chat_id], user: current_user)
      chat ? stream_from("coach:#{chat.id}") : reject
    end
  end
end
