require "test_helper"

class User::AccessorColumnVisibilityTest < ActiveSupport::TestCase
  setup do
    @owner = users(:jason)
    @admin = users(:kevin)
    @member = users(:david)
    @viewer = users(:pat)
    @column = columns(:writebook_in_progress)
  end

  # -- accessible_columns with min_role: member --

  test "admin accessible_columns includes member-min columns" do
    @column.update!(min_role: "member")

    assert_includes @admin.accessible_columns, @column
  end

  test "member accessible_columns includes member-min columns" do
    @column.update!(min_role: "member")

    assert_includes @member.accessible_columns, @column
  end

  test "viewer accessible_columns excludes member-min columns" do
    @column.update!(min_role: "member")

    assert_not_includes @viewer.accessible_columns, @column
  end

  test "viewer accessible_columns includes viewer-min columns" do
    assert_includes @viewer.accessible_columns, columns(:writebook_triage)
  end

  # -- accessible_columns with min_role: admin --

  test "admin accessible_columns includes admin-min columns" do
    @column.update!(min_role: "admin")

    assert_includes @admin.accessible_columns, @column
  end

  test "member accessible_columns excludes admin-min columns" do
    @column.update!(min_role: "admin")

    assert_not_includes @member.accessible_columns, @column
  end

  test "viewer accessible_columns excludes admin-min columns" do
    @column.update!(min_role: "admin")

    assert_not_includes @viewer.accessible_columns, @column
  end

  # -- accessible_cards with min_role: member --

  test "admin accessible_cards includes cards in member-min columns" do
    @column.update!(min_role: "member")
    card = cards(:text)

    assert_includes @admin.accessible_cards, card
  end

  test "member accessible_cards includes cards in member-min columns" do
    @column.update!(min_role: "member")
    card = cards(:text)

    assert_includes @member.accessible_cards, card
  end

  test "viewer accessible_cards excludes cards in member-min columns" do
    @column.update!(min_role: "member")
    card = cards(:text)

    assert_not_includes @viewer.accessible_cards, card
  end

  # -- accessible_cards with min_role: admin --

  test "member accessible_cards excludes cards in admin-min columns" do
    @column.update!(min_role: "admin")
    card = cards(:text)

    assert_not_includes @member.accessible_cards, card
  end

  test "viewer accessible_cards excludes cards in admin-min columns" do
    @column.update!(min_role: "admin")
    card = cards(:text)

    assert_not_includes @viewer.accessible_cards, card
  end

  # -- triage cards always visible --

  test "viewer accessible_cards includes triage cards with no column" do
    card = cards(:buy_domain)

    assert_includes @viewer.accessible_cards, card
  end

  test "member accessible_cards includes triage cards with no column" do
    card = cards(:buy_domain)

    assert_includes @member.accessible_cards, card
  end

  # -- cards in visible columns --

  test "viewer accessible_cards includes cards in viewer-min columns" do
    card = cards(:logo)

    assert_includes @viewer.accessible_cards, card
  end
end
