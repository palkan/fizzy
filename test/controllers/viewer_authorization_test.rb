require "test_helper"

class ViewerAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :pat
  end

  # -- Cards --

  test "viewer cannot create cards" do
    post board_cards_path(boards(:writebook)), as: :json
    assert_response :forbidden
  end

  test "viewer cannot edit cards" do
    get edit_card_path(cards(:logo))
    assert_response :forbidden
  end

  test "viewer cannot update cards" do
    patch card_path(cards(:logo)), params: { card: { title: "Hacked" } }, as: :json
    assert_response :forbidden
  end

  test "viewer can view cards" do
    get card_path(cards(:logo))
    assert_response :success
  end

  # -- Triages --

  test "viewer cannot triage cards" do
    post card_triage_path(cards(:buy_domain), column_id: columns(:writebook_triage).id), as: :json
    assert_response :forbidden
  end

  test "viewer cannot send cards back to triage" do
    delete card_triage_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Closures --

  test "viewer cannot close cards" do
    post card_closure_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  test "viewer cannot reopen cards" do
    delete card_closure_path(cards(:shipping)), as: :json
    assert_response :forbidden
  end

  # -- Not Nows --

  test "viewer cannot postpone cards" do
    post card_not_now_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Goldnesses --

  test "viewer cannot gild cards" do
    post card_goldness_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Assignments --

  test "viewer cannot assign users" do
    post card_assignments_path(cards(:logo)), params: { assignee_id: users(:david).id }, as: :json
    assert_response :forbidden
  end

  # -- Self Assignments --

  test "viewer cannot self-assign" do
    post card_self_assignment_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Steps --

  test "viewer cannot create steps" do
    post card_steps_path(cards(:logo)), params: { step: { content: "Test" } }, as: :json
    assert_response :forbidden
  end

  test "viewer cannot edit steps" do
    Current.session = sessions(:kevin)
    step = cards(:logo).steps.create!(content: "Test step", account: accounts("37s"))

    get edit_card_step_path(cards(:logo), step)
    assert_response :forbidden
  end

  # -- Taggings --

  test "viewer cannot toggle tags" do
    post card_taggings_path(cards(:logo)), params: { tag_title: "test" }, as: :json
    assert_response :forbidden
  end

  # -- Images --

  test "viewer cannot delete images" do
    delete card_image_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Card Boards (move card) --

  test "viewer cannot load card board picker" do
    get edit_card_board_path(cards(:logo))
    assert_response :forbidden
  end

  test "viewer cannot move cards to another board" do
    patch card_board_path(cards(:logo)), params: { board_id: boards(:writebook).id }, as: :json
    assert_response :forbidden
  end

  # -- Publishes --

  test "viewer cannot publish cards" do
    draft = boards(:writebook).cards.create!(creator: users(:david), status: :drafted, account: accounts("37s"))
    post card_publish_path(draft), as: :json
    assert_response :forbidden
  end

  # -- Drafts --

  test "viewer cannot view drafts" do
    draft = boards(:writebook).cards.create!(creator: users(:david), status: :drafted, account: accounts("37s"))
    get card_draft_path(draft)
    assert_response :forbidden
  end

  # -- Column management --

  test "viewer cannot create columns" do
    post board_columns_path(boards(:writebook)), params: { column: { name: "Test", color: "red" } }, as: :json
    assert_response :forbidden
  end

  test "viewer cannot update columns" do
    patch board_column_path(boards(:writebook), columns(:writebook_triage)), params: { column: { name: "Renamed" } }, as: :json
    assert_response :forbidden
  end

  test "viewer cannot delete columns" do
    delete board_column_path(boards(:writebook), columns(:writebook_triage)), as: :json
    assert_response :forbidden
  end

  # -- Column positions --

  test "viewer cannot move columns left" do
    post column_left_position_path(columns(:writebook_in_progress)), as: :json
    assert_response :forbidden
  end

  test "viewer cannot move columns right" do
    post column_right_position_path(columns(:writebook_triage)), as: :json
    assert_response :forbidden
  end

  # -- Drop controllers --

  test "viewer cannot drop cards to close" do
    post columns_card_drops_closure_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  test "viewer cannot drop cards to column" do
    post columns_card_drops_column_path(cards(:logo), column_id: columns(:writebook_in_progress).id), as: :json
    assert_response :forbidden
  end

  test "viewer cannot drop cards to not now" do
    post columns_card_drops_not_now_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  test "viewer cannot drop cards to stream" do
    post columns_card_drops_stream_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Column edit (card column picker) --

  test "viewer cannot load card column picker" do
    get edit_card_column_path(cards(:logo)), as: :json
    assert_response :forbidden
  end

  # -- Board management --

  test "viewer cannot create boards" do
    post boards_path, params: { board: { name: "Test" } }, as: :json
    assert_response :forbidden
  end

  test "viewer cannot edit boards" do
    get edit_board_path(boards(:writebook))
    assert_response :forbidden
  end

  test "viewer can view boards" do
    get board_path(boards(:writebook))
    assert_response :success
  end

  # -- Account settings --

  test "viewer cannot view account settings" do
    get account_settings_path
    assert_response :forbidden
  end

  # -- Join codes --

  test "viewer cannot view join codes" do
    get account_join_code_path
    assert_response :forbidden
  end

  # -- User directory --

  test "viewer cannot view user index" do
    get users_path
    assert_response :forbidden
  end

  test "viewer cannot view user show" do
    get user_path(users(:david))
    assert_response :forbidden
  end

  # -- Comments: special handling --

  test "viewer can comment on triage cards" do
    card = cards(:buy_domain)
    assert card.awaiting_triage?

    assert_difference -> { card.comments.count }, +1 do
      post card_comments_path(card), params: { comment: { body: "Viewer feedback" } }, as: :json
    end

    assert_response :created
  end

  test "viewer cannot comment on triaged cards" do
    card = cards(:logo)
    assert card.triaged?

    assert_no_difference -> { card.comments.count } do
      post card_comments_path(card), params: { comment: { body: "Denied" } }, as: :json
    end

    assert_response :forbidden
  end

  test "viewer can edit own comment on triage card" do
    card = cards(:buy_domain)
    Current.session = sessions(:pat)
    comment = card.comments.create!(body: "Original", creator: users(:pat))

    put card_comment_path(card, comment), params: { comment: { body: "Updated" } }, as: :json
    assert_response :success
  end

  test "viewer cannot edit own comment on triaged card" do
    card = cards(:logo)
    comment = Comment.create!(body: "Old", card: card, creator: users(:pat), account: accounts("37s"))

    put card_comment_path(card, comment), params: { comment: { body: "Updated" } }, as: :json
    assert_response :forbidden
  end

  # -- Reactions --

  test "viewer cannot react to cards" do
    post card_reactions_path(cards(:logo)), params: { reaction: { content: "👍" } }, as: :json
    assert_response :forbidden
  end

  test "viewer cannot react to comments" do
    post card_comment_reactions_path(cards(:logo), comments(:logo_1)), params: { reaction: { content: "👍" } }, as: :json
    assert_response :forbidden
  end

  # -- Allowed personal features --

  test "viewer can view boards index" do
    get boards_path, as: :json
    assert_response :success
  end

  test "viewer can view activity timeline" do
    get events_path
    assert_response :success
  end

  test "viewer can search" do
    get search_path
    assert_response :success
  end
end
