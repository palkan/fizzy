require "test_helper"

class Column::ViewerVisibilityTest < ActiveSupport::TestCase
  test "visible_to returns all columns for contributors" do
    column = columns(:writebook_triage)
    column.update!(hidden_from_viewers: true)

    assert_includes Column.visible_to(users(:kevin)), column
  end

  test "visible_to excludes hidden columns for viewers" do
    column = columns(:writebook_triage)
    column.update!(hidden_from_viewers: true)

    assert_not_includes Column.visible_to(users(:pat)), column
  end

  test "visible_to includes non-hidden columns for viewers" do
    column = columns(:writebook_triage)

    assert_includes Column.visible_to(users(:pat)), column
  end

  test "visible_to excludes hidden columns for nil user" do
    column = columns(:writebook_triage)
    column.update!(hidden_from_viewers: true)

    assert_not_includes Column.visible_to(nil), column
  end

  test "viewer_visible excludes hidden columns" do
    column = columns(:writebook_triage)
    column.update!(hidden_from_viewers: true)

    assert_not_includes Column.viewer_visible, column
  end

  test "viewer_visible includes non-hidden columns" do
    column = columns(:writebook_triage)

    assert_includes Column.viewer_visible, column
  end
end
