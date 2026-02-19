class Cards::StepsController < ApplicationController
  include CardScoped

  verify_authorized

  before_action :set_step, only: %i[ show edit update destroy ]

  def create
    authorize! @card, to: :manage?
    @step = @card.steps.create!(step_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :created, location: card_step_path(@card, @step, format: :json) }
    end
  end

  def show
  end

  def edit
  end

  def update
    authorize! @card, to: :manage?
    @step.update!(step_params)

    respond_to do |format|
      format.turbo_stream
      format.json { render :show }
    end
  end

  def destroy
    authorize! @card, to: :manage?
    @step.destroy!

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def set_step
      @step = @card.steps.find(params[:id])
    end

    def step_params
      params.expect(step: [ :content, :completed ])
    end
end
