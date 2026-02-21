class Boards::ColumnsController < ApplicationController
  include BoardScoped

  verify_authorized

  before_action :set_column, only: %i[ show update destroy ]

  def index
    @columns = @board.columns.sorted.accessible_by(Current.user)
    fresh_when etag: @columns
  end

  def show
    set_page_and_extract_portion_from @column.cards.active.latest.with_golden_first.preloaded
    fresh_when etag: @page.records
  end

  def create
    authorize!
    @column = @board.columns.create!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :created, location: board_column_path(@board, @column, format: :json) }
    end
  end

  def update
    @column.update!(column_params)

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def destroy
    @column.destroy

    respond_to do |format|
      format.html { redirect_back_or_to @board }
      format.json { head :no_content }
    end
  end

  private
    def set_column
      @column = @board.columns.find(params[:id])
      authorize! @column
    end

    def column_params
      params.expect(column: [ :name, :color, :min_role ])
    end
end
