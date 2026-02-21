require "test_helper"

class CardPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "admin can show card" do
    policy = CardPolicy.new(@card, user: users(:kevin), account: @account)
    assert policy.apply(:show?)
  end

  test "member with access can show card" do
    policy = CardPolicy.new(@card, user: users(:david), account: @account)
    assert policy.apply(:show?)
  end

  test "member without board access cannot show card" do
    # JZ has access to writebook, but if we remove it...
    accesses(:writebook_jz).destroy
    @board.update!(all_access: false)
    policy = CardPolicy.new(@card, user: users(:jz), account: @account)

    assert_not policy.apply(:show?)
  end

  test "admin can update card" do
    policy = CardPolicy.new(@card, user: users(:kevin), account: @account)
    assert policy.apply(:update?)
  end

  test "member with access can update card" do
    policy = CardPolicy.new(@card, user: users(:david), account: @account)
    assert policy.apply(:update?)
  end

  test "card creator can destroy their own card" do
    # David is the creator of the logo card
    policy = CardPolicy.new(@card, user: users(:david), account: @account)
    assert policy.apply(:destroy?)
  end

  test "admin can destroy any card" do
    policy = CardPolicy.new(@card, user: users(:kevin), account: @account)
    assert policy.apply(:destroy?)
  end

  test "non-creator member cannot destroy card" do
    # JZ is a member with access but not the creator
    policy = CardPolicy.new(@card, user: users(:jz), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "edit? is aliased to update?" do
    policy = CardPolicy.new(@card, user: users(:david), account: @account)
    assert policy.apply(:edit?)
  end

  test "show? delegates to board policy" do
    # Create a card on the private board that david can't access
    kevin = users(:kevin)
    private_board = boards(:private)

    Current.user = kevin
    private_card = private_board.cards.create!(
      title: "Private card",
      account: @account,
      status: "published"
    )

    # Kevin can see it (has access)
    kevin_policy = CardPolicy.new(private_card, user: kevin, account: @account)
    assert kevin_policy.apply(:show?)

    # David cannot (no access to private board)
    david_policy = CardPolicy.new(private_card, user: users(:david), account: @account)
    assert_not david_policy.apply(:show?)
  end

  test "viewer can show card on accessible board" do
    policy = CardPolicy.new(@card, user: users(:pat), account: @account)
    assert policy.apply(:show?)
  end

  test "viewer cannot create card" do
    policy = CardPolicy.new(board: @board, user: users(:pat), account: @account)
    assert_not policy.apply(:create?)
  end

  test "viewer cannot manage card" do
    policy = CardPolicy.new(@card, user: users(:pat), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "viewer cannot destroy card" do
    policy = CardPolicy.new(@card, user: users(:pat), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "relation scope returns only cards from accessible boards" do
    david = users(:david)
    kevin = users(:kevin)

    # Create a card on the private board that david can't access
    private_board = boards(:private)
    Current.user = kevin
    private_card = private_board.cards.create!(
      title: "Private card",
      account: @account,
      status: "published"
    )

    accessible_cards = CardPolicy.new(Card, user: david, account: @account)
      .apply_scope(Card.all, type: :active_record_relation)

    assert_includes accessible_cards, @card
    assert_not_includes accessible_cards, private_card
  end
end
