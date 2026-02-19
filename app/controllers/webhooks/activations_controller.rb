class Webhooks::ActivationsController < ApplicationController
  include BoardScoped

  verify_authorized

  def create
    webhook = @board.webhooks.find(params[:webhook_id])
    authorize! webhook, to: :update?
    webhook.activate

    redirect_to webhook
  end
end
