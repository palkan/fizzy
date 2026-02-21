require "test_helper"

class Column::RoleVisibilityTest < ActiveSupport::TestCase
  setup do
    @column = columns(:writebook_triage)
  end

  # -- visible_to with min_role: viewer (default) --

  test "visible_to returns viewer-min columns for all roles" do
    assert_includes Column.visible_to(users(:jason)), @column  # owner
    assert_includes Column.visible_to(users(:kevin)), @column  # admin
    assert_includes Column.visible_to(users(:david)), @column  # member
    assert_includes Column.visible_to(users(:pat)), @column    # viewer
    assert_includes Column.visible_to(nil), @column            # public
  end

  # -- visible_to with min_role: member --

  test "visible_to returns member-min columns for members and above" do
    @column.update!(min_role: "member")

    assert_includes Column.visible_to(users(:jason)), @column  # owner
    assert_includes Column.visible_to(users(:kevin)), @column  # admin
    assert_includes Column.visible_to(users(:david)), @column  # member
  end

  test "visible_to excludes member-min columns for viewers" do
    @column.update!(min_role: "member")

    assert_not_includes Column.visible_to(users(:pat)), @column
  end

  test "visible_to excludes member-min columns for nil user" do
    @column.update!(min_role: "member")

    assert_not_includes Column.visible_to(nil), @column
  end

  # -- visible_to with min_role: admin --

  test "visible_to returns admin-min columns for admins and owners" do
    @column.update!(min_role: "admin")

    assert_includes Column.visible_to(users(:jason)), @column  # owner
    assert_includes Column.visible_to(users(:kevin)), @column  # admin
  end

  test "visible_to excludes admin-min columns for members" do
    @column.update!(min_role: "admin")

    assert_not_includes Column.visible_to(users(:david)), @column
  end

  test "visible_to excludes admin-min columns for viewers" do
    @column.update!(min_role: "admin")

    assert_not_includes Column.visible_to(users(:pat)), @column
  end

  test "visible_to excludes admin-min columns for nil user" do
    @column.update!(min_role: "admin")

    assert_not_includes Column.visible_to(nil), @column
  end

  # -- publicly_visible --

  test "publicly_visible includes viewer-min columns" do
    assert_includes Column.publicly_visible, @column
  end

  test "publicly_visible excludes member-min columns" do
    @column.update!(min_role: "member")

    assert_not_includes Column.publicly_visible, @column
  end

  test "publicly_visible excludes admin-min columns" do
    @column.update!(min_role: "admin")

    assert_not_includes Column.publicly_visible, @column
  end

  # -- restricted? --

  test "restricted? returns false for viewer-min columns" do
    assert_not @column.restricted?
  end

  test "restricted? returns true for member-min columns" do
    @column.update!(min_role: "member")

    assert @column.restricted?
  end

  test "restricted? returns true for admin-min columns" do
    @column.update!(min_role: "admin")

    assert @column.restricted?
  end
end
