require "test_helper"

class ColumnPolicyTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @column = columns(:writebook_triage)
  end

  test "user with board access can view column" do
    policy = ColumnPolicy.new(@column, user: users(:jz), account: @account)
    assert policy.apply(:show?)
  end

  test "board admin can create columns" do
    policy = ColumnPolicy.new(board: @board, user: users(:david), account: @account)
    assert policy.apply(:create?)
  end

  test "non-admin cannot add columns" do
    policy = ColumnPolicy.new(board: @board, user: users(:jz), account: @account)
    assert_not policy.apply(:create?)
  end

  test "board admin can update column" do
    policy = ColumnPolicy.new(@column, user: users(:david), account: @account)
    assert policy.apply(:update?)
  end

  test "non-admin cannot update column" do
    policy = ColumnPolicy.new(@column, user: users(:jz), account: @account)
    assert_not policy.apply(:update?)
  end

  test "board admin can destroy column" do
    policy = ColumnPolicy.new(@column, user: users(:david), account: @account)
    assert policy.apply(:destroy?)
  end

  test "non-admin cannot destroy column" do
    policy = ColumnPolicy.new(@column, user: users(:jz), account: @account)
    assert_not policy.apply(:destroy?)
  end

  test "account admin can manage any column" do
    policy = ColumnPolicy.new(@column, user: users(:kevin), account: @account)

    assert policy.apply(:update?)
    assert policy.apply(:destroy?)
  end

  test "account admin can add columns to any board" do
    policy = ColumnPolicy.new(board: @board, user: users(:kevin), account: @account)
    assert policy.apply(:create?)
  end
end
