require "test_helper"

class Public::ColumnVisibilityTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    boards(:writebook).publish
    @key = boards(:writebook).publication.key
  end

  test "hidden columns are not visible on published board" do
    columns(:writebook_in_progress).update!(hidden_from_viewers: true)

    sign_out
    get public_board_path(@key)
    assert_response :success
    assert_no_match "In progress", response.body
  end

  test "hidden column cannot be accessed directly on published board" do
    column = columns(:writebook_in_progress)
    column.update!(hidden_from_viewers: true)

    sign_out
    get public_board_column_path(@key, column)
    assert_response :not_found
  end

  test "card in hidden column cannot be accessed on published board" do
    columns(:writebook_in_progress).update!(hidden_from_viewers: true)
    card = cards(:text) # in writebook_in_progress

    sign_out
    get public_board_card_path(@key, card)
    assert_response :not_found
  end

  test "closed cards from hidden columns are not visible on published board" do
    card = cards(:text) # in writebook_in_progress
    with_current_user(:kevin) { card.close }
    columns(:writebook_in_progress).update!(hidden_from_viewers: true)

    sign_out
    get public_board_columns_closed_path(@key)
    assert_response :success
    assert_no_match card.title, response.body
  end
end
