class Cards::AssignmentsController < ApplicationController
  include CardScoped

  verify_authorized

  def new
    @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
    @users = assignable_users.alphabetically.where.not(id: @card.assignees).where.not(id: Current.user)
    fresh_when etag: [ @users, @card.assignees ]
  end

  def create
    authorize! @card, to: :manage?
    if @card.toggle_assignment assignable_users.find(params[:assignee_id])
      respond_to do |format|
        format.turbo_stream
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.json { head :unprocessable_entity }
      end
    end
  end

  private
    def assignable_users
      authorized_scope(@board.users.active, type: :active_record_relation, as: :assignable, with: UserPolicy)
    end
end
