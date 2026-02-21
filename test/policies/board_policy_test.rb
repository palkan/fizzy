require "test_helper"

class BoardPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
  end

  test "admin can show any board they have access to" do
    policy = BoardPolicy.new(@board, user: users(:kevin), account: @account)
    assert policy.apply(:show?)
  end

  test "member with access can show board" do
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:show?)
  end

  test "member without access cannot show board" do
    private_board = boards(:private)
    policy = BoardPolicy.new(private_board, user: users(:david), account: @account)

    assert_not policy.apply(:show?)
  end




  test "admin can update any board" do
    policy = BoardPolicy.new(@board, user: users(:kevin), account: @account)
    assert policy.apply(:update?)
  end

  test "board creator can update their own board" do
    # David created the writebook board
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:update?)
  end

  test "non-creator member cannot update board" do
    policy = BoardPolicy.new(@board, user: users(:jz), account: @account)
    assert_not policy.apply(:update?)
  end

  test "admin can destroy any board" do
    policy = BoardPolicy.new(@board, user: users(:kevin), account: @account)
    assert policy.apply(:destroy?)
  end

  test "board creator can destroy their own board" do
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:destroy?)
  end

  test "non-creator member cannot destroy board" do
    policy = BoardPolicy.new(@board, user: users(:jz), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "edit? is aliased to manage?" do
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:edit?)
  end

  test "relation scope returns only accessible boards" do
    david = users(:david)

    accessible_boards = BoardPolicy.new(Board, user: david, account: @account)
      .apply_scope(Board.all, type: :active_record_relation)

    assert_includes accessible_boards, @board
    assert_not_includes accessible_boards, boards(:private)
  end

  test "relation scope includes all_access boards without explicit access" do
    jz = users(:jz)
    # writebook is all_access: true — jz should see it even if their access record were removed
    @board.accesses.where(user: jz).destroy_all

    accessible_boards = BoardPolicy.new(Board, user: jz, account: @account)
      .apply_scope(Board.all, type: :active_record_relation)

    assert_includes accessible_boards, @board
  end

  test "relation scope does not return duplicates for all_access boards with explicit access" do
    david = users(:david)
    # writebook is all_access: true AND david has an explicit access record
    assert @board.all_access?
    assert @board.accesses.exists?(user: david)

    accessible_boards = BoardPolicy.new(Board, user: david, account: @account)
      .apply_scope(Board.all, type: :active_record_relation)

    assert_equal 1, accessible_boards.where(id: @board.id).count
  end

  # manage? covers: publications, webhooks, inbound address, entropy, column CRUD
  test "board creator can manage board" do
    policy = BoardPolicy.new(@board, user: users(:david), account: @account)
    assert policy.apply(:manage?)
  end

  test "account admin can manage any board" do
    policy = BoardPolicy.new(@board, user: users(:kevin), account: @account)
    assert policy.apply(:manage?)
  end

  test "non-admin member cannot manage board" do
    policy = BoardPolicy.new(@board, user: users(:jz), account: @account)
    assert_not policy.apply(:manage?)
  end

  test "viewer can show accessible board" do
    policy = BoardPolicy.new(@board, user: users(:pat), account: @account)
    assert policy.apply(:show?)
  end

  test "viewer cannot create board" do
    policy = BoardPolicy.new(Board, user: users(:pat), account: @account)
    assert_not policy.apply(:create?)
  end

  test "viewer cannot manage board" do
    policy = BoardPolicy.new(@board, user: users(:pat), account: @account)
    assert_not policy.apply(:manage?)
  end
end
