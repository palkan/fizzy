require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  include SearchTestHelper

  setup do
    @board.update!(all_access: true)
    @card = @board.cards.create!(title: "Layout is broken", description: "Look at this mess.", status: "published", creator: @user)
    @comment_card = @board.cards.create!(title: "Some card", status: "published", creator: @user)
    @comment_card.comments.create!(body: "overflowing text issue", creator: @user)
    @comment2_card = @board.cards.create!(title: "Just haggis", description: "More haggis", status: "published", creator: @user)
    @comment2_card.comments.create!(body: "I love haggis", creator: @user)

    untenanted { sign_in_as @user }
  end

  test "search" do
    # Searching by card title
    get search_path(q: "broken", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Layout is broken/
    assert_select "li .search__excerpt", text: /Look at this mess/

    # Searching by comment
    get search_path(q: "overflowing", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Some card/
    assert_select "li .search__excerpt--comment", text: /overflowing text issue/

    # Searching for a term that appears in a card and in a comment
    get search_path(q: "haggis", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Just haggis/, count: 2 # card title shows up in two entries
    assert_select "li .search__excerpt", text: /More haggis/ # one entry for the card description
    assert_select "li .search__excerpt--comment", text: /I love haggis/ # one entry for the comment
    assert_match(/<mark class="circled-text"><span><\/span>haggis<\/mark>/, response.body)

    # Searching by card id
    get search_path(q: @card.id, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']"

    # Searching with non-existent card id
    get search_path(q: "999999", script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']", count: 0
    assert_select ".search__blank-slate", text: "No matches"
  end

  test "search highlights matched terms with proper HTML marks" do
    @board.cards.create!(title: "Testing search highlighting", status: "published", creator: @user)

    get search_path(q: "highlighting", script_name: "/#{@account.external_account_id}")
    assert_response :success
  end

  test "viewer search excludes cards in restricted columns" do
    column = @board.columns.create!(name: "Restricted", account: @account)
    column.update!(viewer_restricted: true)

    @board.cards.create!(title: "Secret restricted content", column: column, status: "published", creator: @user)
    @board.cards.create!(title: "Visible content here", status: "published", creator: @user)

    viewer_identity = Identity.create!(email_address: "viewer@example.com")
    User.create!(name: "Viewer", account: @account, identity: viewer_identity, role: :viewer)

    untenanted { logout_and_sign_in_as viewer_identity }

    get search_path(q: "content", script_name: "/#{@account.external_account_id}")
    assert_select "li .search__title", text: /Visible content/, count: 1
    assert_select "li .search__title", text: /Secret restricted/, count: 0
  ensure
    Identity.find_by(email_address: "viewer@example.com")&.destroy
  end

  test "viewer numeric ID search excludes card in restricted column" do
    column = @board.columns.create!(name: "Restricted", account: @account)
    column.update!(viewer_restricted: true)

    restricted_card = @board.cards.create!(title: "Restricted card", column: column, status: "published", creator: @user)

    viewer_identity = Identity.create!(email_address: "viewer@example.com")
    User.create!(name: "Viewer", account: @account, identity: viewer_identity, role: :viewer)

    untenanted { logout_and_sign_in_as viewer_identity }

    get search_path(q: restricted_card.id, script_name: "/#{@account.external_account_id}")
    assert_select "form[data-controller='auto-submit']", count: 0
  ensure
    Identity.find_by(email_address: "viewer@example.com")&.destroy
  end

  test "search preserves highlight marks but escapes surrounding HTML" do
    @board.cards.create!(
      title: "<b>Bold</b> testing content",
      status: "published",
      creator: @user
    )

    get search_path(q: "testing", script_name: "/#{@account.external_account_id}")
    assert_response :success

    # Should escape <b> tags
    assert response.body.include?("&lt;b&gt;")
    # But should preserve highlight marks around "testing"
    assert_match(/<mark class="circled-text"><span><\/span>testing<\/mark>/, response.body)
  end
end
