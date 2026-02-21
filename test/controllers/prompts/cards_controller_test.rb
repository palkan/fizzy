require "test_helper"

class Prompts::CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get prompts_cards_path
    assert_response :success
  end

  test "viewer index excludes cards in restricted columns" do
    board = boards(:writebook)
    column = columns(:writebook_on_hold) # min_role: member

    Current.user = users(:kevin)
    restricted_card = board.cards.create!(title: "Restricted card", column: column, status: "published", creator: users(:kevin))

    logout_and_sign_in_as :pat

    get prompts_cards_path(filter: "Restricted card")
    assert_response :success
    assert_not_includes @response.body, restricted_card.title
  end
end
