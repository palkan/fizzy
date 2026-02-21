require "test_helper"

class Boards::ColumnVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    @hidden_column = columns(:writebook_in_progress)
    @hidden_column.update!(hidden_from_viewers: true)
  end

  # -- Viewer cannot see hidden columns --

  test "viewer cannot see hidden columns in index" do
    sign_in_as :pat

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_not_includes column_ids, @hidden_column.id
  end

  test "viewer gets 404 when accessing hidden column" do
    sign_in_as :pat

    get board_column_path(boards(:writebook), @hidden_column)
    assert_response :not_found
  end

  test "viewer gets 404 when accessing card in hidden column" do
    sign_in_as :pat
    card = cards(:text) # in writebook_in_progress (hidden)

    get card_path(card)
    assert_response :not_found
  end

  # -- Contributors see all columns --

  test "contributor can see hidden columns in index" do
    sign_in_as :kevin

    get board_columns_path(boards(:writebook)), as: :json
    assert_response :success

    column_ids = @response.parsed_body.pluck("id")
    assert_includes column_ids, @hidden_column.id
  end

  test "contributor can access hidden column" do
    sign_in_as :kevin

    get board_column_path(boards(:writebook), @hidden_column)
    assert_response :success
  end

  test "contributor can toggle hidden_from_viewers" do
    sign_in_as :kevin
    column = columns(:writebook_triage)

    patch board_column_path(boards(:writebook), column),
      params: { column: { hidden_from_viewers: true } }, as: :json

    assert_response :no_content
    assert column.reload.hidden_from_viewers?
  end

  # -- Closed cards in hidden columns --

  test "viewer cannot see closed cards from hidden columns" do
    card = cards(:text)

    with_current_user(:kevin) { card.close }

    sign_in_as :pat

    get board_columns_closed_path(boards(:writebook))
    assert_response :success
    assert_no_match card.title, response.body
  end

  test "contributor can see closed cards from hidden columns" do
    card = cards(:text)

    with_current_user(:kevin) { card.close }

    sign_in_as :kevin

    get board_columns_closed_path(boards(:writebook))
    assert_response :success
    assert_match card.title, response.body
  end
end
