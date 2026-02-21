require "test_helper"

class Boards::ColumnVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @column = columns(:writebook_in_progress)
  end

  # -- Viewer cannot see member-min columns --

  test "viewer cannot see member-min columns in index" do
    @column.update!(min_role: "member")
    sign_in_as :pat

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_not_includes column_ids, @column.id
  end

  test "viewer gets 404 when accessing member-min column" do
    @column.update!(min_role: "member")
    sign_in_as :pat

    get board_column_path(boards(:writebook), @column)
    assert_response :not_found
  end

  test "viewer gets 404 when accessing card in member-min column" do
    @column.update!(min_role: "member")
    sign_in_as :pat
    card = cards(:text)

    get card_path(card)
    assert_response :not_found
  end

  # -- Member cannot see admin-min columns --

  test "member cannot see admin-min columns in index" do
    @column.update!(min_role: "admin")
    sign_in_as :david

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_not_includes column_ids, @column.id
  end

  test "member gets 404 when accessing admin-min column" do
    @column.update!(min_role: "admin")
    sign_in_as :david

    get board_column_path(boards(:writebook), @column)
    assert_response :not_found
  end

  test "member gets 404 when accessing card in admin-min column" do
    @column.update!(min_role: "admin")
    sign_in_as :david
    card = cards(:text)

    get card_path(card)
    assert_response :not_found
  end

  # -- Member can see member-min columns --

  test "member can see member-min columns in index" do
    @column.update!(min_role: "member")
    sign_in_as :david

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_includes column_ids, @column.id
  end

  # -- Admin sees all columns --

  test "admin can see admin-min columns in index" do
    @column.update!(min_role: "admin")
    sign_in_as :kevin

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_includes column_ids, @column.id
  end

  test "admin can access admin-min column" do
    @column.update!(min_role: "admin")
    sign_in_as :kevin

    get board_column_path(boards(:writebook), @column)
    assert_response :success
  end

  test "admin can set min_role on column" do
    sign_in_as :kevin

    patch board_column_path(boards(:writebook), @column),
      params: { column: { min_role: "admin" } }, as: :json

    assert_response :no_content
    assert_equal "admin", @column.reload.min_role
  end

  # -- Only board admins can change min_role --

  test "non-admin member cannot set min_role on column" do
    sign_in_as :jz

    patch board_column_path(boards(:writebook), @column),
      params: { column: { min_role: "admin" } }, as: :json

    assert_response :no_content
    assert_equal "viewer", @column.reload.min_role
  end

  # -- Closed cards in restricted columns --

  test "viewer cannot see closed cards from member-min columns" do
    @column.update!(min_role: "member")
    card = cards(:text)

    with_current_user(:kevin) { card.close }

    sign_in_as :pat

    get board_columns_closed_path(boards(:writebook))
    assert_response :success
    assert_no_match card.title, response.body
  end

  test "member cannot see closed cards from admin-min columns" do
    @column.update!(min_role: "admin")
    card = cards(:text)

    with_current_user(:kevin) { card.close }

    sign_in_as :david

    get board_columns_closed_path(boards(:writebook))
    assert_response :success
    assert_no_match card.title, response.body
  end

  test "admin can see closed cards from admin-min columns" do
    @column.update!(min_role: "admin")
    card = cards(:text)

    with_current_user(:kevin) { card.close }

    sign_in_as :kevin

    get board_columns_closed_path(boards(:writebook))
    assert_response :success
    assert_match card.title, response.body
  end
end
