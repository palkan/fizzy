class CommentPolicy < ApplicationPolicy
  # Card is only required for some rules
  authorize :card, optional: true

  def create?
    if viewer?
      check?(:card_awaiting_triage?) && allowed_to?(:show?, card)
    else
      allowed_to?(:show?, card)
    end
  end

  def show?
    allowed_to?(:show?, record.card)
  end

  def manage?
    check?(:not_viewer?) && allowed_to?(:show?) && check?(:creator?)
  end

  def creator?
    record.creator == user
  end

  def card_awaiting_triage?
    card&.awaiting_triage?
  end
end
