# typed: true

# @requires_ancestor: ApplicationController
module ColumnScoped
  extend ActiveSupport::Concern

  included do
    #: self as singleton(ApplicationController)
    before_action :set_column
  end

  private
    def set_column
      @column = Current.user!.accessible_columns.find(params[:column_id])
    end
end
