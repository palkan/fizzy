module ColumnScoped
  # @type instance: ApplicationController
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ApplicationController)
    before_action :set_column
  end

  private
    def set_column
      @column = Current.user!.accessible_columns.find(params[:column_id])
    end
end
