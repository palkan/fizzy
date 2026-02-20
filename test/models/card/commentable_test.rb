require "test_helper"

class Card::CommentableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "capturing comments" do
    assert_difference -> { cards(:logo).comments.count }, +1 do
      cards(:logo).comments.create!(body: "Agreed.")
    end

    assert_equal "Agreed.", cards(:logo).comments.last.body.to_plain_text.chomp
  end

  test "creating a comment on a card makes the creator watch the card" do
    boards(:writebook).access_for(users(:kevin)).access_only!
    assert_not cards(:text).watched_by?(users(:kevin))

    with_current_user(:kevin) do
      cards(:text).comments.create!(body: "This sounds interesting!")
    end

    assert cards(:text).watched_by?(users(:kevin))
  end

  test "commentable is true for published cards, false for drafts" do
    assert cards(:logo).commentable?
    assert_not cards(:unfinished_thoughts).commentable?
  end

  test "commentable_by? allows contributors on any published card" do
    assert cards(:logo).commentable_by?(users(:david))
    assert cards(:buy_domain).commentable_by?(users(:david))
  end

  test "commentable_by? allows viewers only on triage cards" do
    assert cards(:buy_domain).commentable_by?(users(:pat))
    assert cards(:buy_domain).awaiting_triage?
  end

  test "commentable_by? denies viewers on triaged cards" do
    assert_not cards(:logo).commentable_by?(users(:pat))
    assert cards(:logo).triaged?
  end
end
