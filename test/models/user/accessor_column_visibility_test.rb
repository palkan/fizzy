require "test_helper"

class User::AccessorColumnVisibilityTest < ActiveSupport::TestCase
  setup do
    @viewer = users(:pat)
    @contributor = users(:kevin)
    @hidden_column = columns(:writebook_in_progress)
    @hidden_column.update!(hidden_from_viewers: true)
  end

  test "contributor accessible_columns includes hidden columns" do
    assert_includes @contributor.accessible_columns, @hidden_column
  end

  test "viewer accessible_columns excludes hidden columns" do
    assert_not_includes @viewer.accessible_columns, @hidden_column
  end

  test "viewer accessible_columns includes non-hidden columns" do
    assert_includes @viewer.accessible_columns, columns(:writebook_triage)
  end

  test "contributor accessible_cards includes cards in hidden columns" do
    card = cards(:text) # in writebook_in_progress
    assert_includes @contributor.accessible_cards, card
  end

  test "viewer accessible_cards excludes cards in hidden columns" do
    card = cards(:text) # in writebook_in_progress
    assert_not_includes @viewer.accessible_cards, card
  end

  test "viewer accessible_cards includes triage cards with no column" do
    card = cards(:buy_domain) # no column (triage)
    assert_includes @viewer.accessible_cards, card
  end

  test "viewer accessible_cards includes cards in visible columns" do
    card = cards(:logo) # in writebook_triage (not hidden)
    assert_includes @viewer.accessible_cards, card
  end
end
