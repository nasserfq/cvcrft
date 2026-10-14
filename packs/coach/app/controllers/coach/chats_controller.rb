module Coach
  class ChatsController < ApplicationController
    before_action :authenticate_user!, :require_coach!
    before_action :set_chat, only: %i[show message]

    def index
    end

    def create
      chat = Coach::Chat.create!(user: current_user, path: params[:path])
      redirect_to coach_chat_path(chat)
    end

    def show
      @messages = @chat.messages.order(:id).map { |m| m.slice(:id, :role, :content) }
    end

    def message
      message = @chat.messages.new(role: "user", content: params[:content])
      return head :unprocessable_entity unless message.save

      Coach::TurnJob.perform_later(@chat.id)
      head :accepted
    end

    private

    def require_coach!
      raise ActionController::RoutingError, "Not Found" unless Coach.enabled_for?(current_user)
    end

    def set_chat
      @chat = Coach::Chat.where(user: current_user).find(params[:id])
    end
  end
end
