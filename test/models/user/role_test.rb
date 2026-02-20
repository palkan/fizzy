require "test_helper"

class User::RoleTest < ActiveSupport::TestCase
  test "can administer others?" do
    assert users(:kevin).can_administer?(users(:jz))

    assert_not users(:kevin).can_administer?(users(:kevin))
    assert_not users(:jz).can_administer?(users(:kevin))
  end

  test "owner can administer admins and members" do
    assert users(:jason).can_administer?(users(:kevin))
    assert users(:jason).can_administer?(users(:david))
    assert users(:jason).can_administer?(users(:jz))
  end

  test "owner cannot administer themselves" do
    assert_not users(:jason).can_administer?(users(:jason))
  end

  test "admin cannot administer the owner" do
    assert_not users(:kevin).can_administer?(users(:jason))
  end

  test "owner is included in active scope" do
    active_users = User.active
    assert_includes active_users, users(:jason)
    assert_includes active_users, users(:kevin)
    assert_includes active_users, users(:david)
    assert_not_includes active_users, users(:system)
  end

  test "owner is also considered an admin" do
    assert users(:jason).owner?
    assert users(:jason).admin?

    assert users(:kevin).admin?
    assert_not users(:kevin).owner?
  end

  test "owner scope returns only active owners" do
    owners = accounts("37s").users.owner
    assert_includes owners, users(:jason)
    assert_not_includes owners, users(:kevin)
    assert_not_includes owners, users(:david)

    users(:jason).update!(active: false)
    assert_not_includes accounts("37s").users.owner, users(:jason)
  end

  test "admin scope returns active owners and admins" do
    admins = accounts("37s").users.admin
    assert_includes admins, users(:jason)
    assert_includes admins, users(:kevin)
    assert_not_includes admins, users(:david)

    users(:kevin).update!(active: false)
    assert_not_includes accounts("37s").users.admin, users(:kevin)
  end

  test "can administer board?" do
    writebook_board = boards(:writebook)
    private_board = boards(:private)

    # Admin can administer any board
    assert users(:kevin).can_administer_board?(writebook_board)
    assert users(:kevin).can_administer_board?(private_board)

    # Creator can administer their own board
    assert users(:david).can_administer_board?(writebook_board)

    # Regular user cannot administer boards they didn't create
    assert_not users(:jz).can_administer_board?(writebook_board)
    assert_not users(:jz).can_administer_board?(private_board)

    # Creator cannot administer other people's boards
    assert_not users(:david).can_administer_board?(private_board)
  end

  test "can administer card?" do
    logo_card = cards(:logo)
    text_card = cards(:text)

    # Admin can administer any card
    assert users(:kevin).can_administer_card?(logo_card)
    assert users(:kevin).can_administer_card?(text_card)

    # Creator can administer their own card
    assert users(:david).can_administer_card?(logo_card)

    # Regular user cannot administer cards they didn't create
    assert_not users(:jz).can_administer_card?(logo_card)
    assert_not users(:jz).can_administer_card?(text_card)

    # Creator cannot administer other people's cards
    assert_not users(:david).can_administer_card?(text_card)
  end

  test "contributor? returns true for owner, admin, member" do
    assert users(:jason).contributor?
    assert users(:kevin).contributor?
    assert users(:david).contributor?
  end

  test "contributor? returns false for viewer and system" do
    assert_not users(:pat).contributor?
    assert_not users(:system).contributor?
  end

  test "viewer is included in active scope" do
    assert_includes User.active, users(:pat)
  end

  test "contributor scope excludes viewers" do
    assert_not_includes User.contributor, users(:pat)
    assert_includes User.contributor, users(:david)
  end

  test "viewer cannot administer board even as creator" do
    board = boards(:writebook)
    board.update_column(:creator_id, users(:pat).id)

    assert_not users(:pat).can_administer_board?(board)
  end

  test "viewer cannot administer card even as creator" do
    card = cards(:logo)
    card.update_column(:creator_id, users(:pat).id)

    assert_not users(:pat).can_administer_card?(card)
  end

  test "demotion to viewer removes assignments" do
    user = users(:david)
    card = cards(:logo)

    Current.session = sessions(:kevin)
    card.toggle_assignment(user)
    assert card.assigned_to?(user)

    user.update!(role: :viewer)
    assert_not card.reload.assigned_to?(user)
  end

  test "demotion to viewer deletes drafted cards" do
    user = users(:david)
    board = boards(:writebook)
    draft = board.cards.create!(creator: user, status: :drafted, account: accounts("37s"))

    user.update!(role: :viewer)
    assert_not Card.exists?(draft.id)
  end

  test "demotion to viewer does not delete published cards" do
    user = users(:david)

    user.update!(role: :viewer)
    assert Card.exists?(cards(:logo).id)
  end

  test "admin can administer viewer" do
    assert users(:kevin).can_administer?(users(:pat))
  end
end
