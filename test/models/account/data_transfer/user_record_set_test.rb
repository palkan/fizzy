require "test_helper"

class Account::DataTransfer::UserRecordSetTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  test "export writes each of the account's users with their email address" do
    account = accounts("37s")
    zip = written_zip { |writer| record_set(account).export(to: writer) }

    assert_equal account.users.map { "data/users/#{it.id}.json" }.sort, zip.glob("data/users/*.json")
    assert_equal "david@37signals.com", JSON.parse(zip.read("data/users/#{users(:david).id}.json"))["email_address"]
    assert_nil JSON.parse(zip.read("data/users/#{users(:system).id}.json"))["email_address"]
  end

  test "import connects users to the identity with their email address" do
    account = accounts(:acme)
    data = user_data(email_address: "david@37signals.com")

    record_set(account).import(from: zip_of("data/users/#{data["id"]}.json" => data.to_json))

    assert_equal identities(:david), account.users.find(data["id"]).identity
  end

  test "import creates identities for new email addresses" do
    account = accounts(:acme)
    data = user_data(email_address: "newcomer@example.com")

    assert_difference -> { Identity.count }, +1 do
      record_set(account).import(from: zip_of("data/users/#{data["id"]}.json" => data.to_json))
    end
    assert_equal "newcomer@example.com", account.users.find(data["id"]).identity.email_address
  end

  test "import leaves users without an email address without an identity" do
    account = accounts(:acme)
    data = user_data(email_address: nil)

    record_set(account).import(from: zip_of("data/users/#{data["id"]}.json" => data.to_json))

    assert_nil account.users.find(data["id"]).identity
  end

  test "import replaces the account's user for an identity it brings again" do
    account = accounts(:initech)
    existing = users(:mike)
    data = user_data(email_address: existing.identity.email_address)

    record_set(account).import(from: zip_of("data/users/#{data["id"]}.json" => data.to_json))

    assert_not User.exists?(existing.id)
    assert_equal identities(:mike), account.users.find(data["id"]).identity
  end

  test "check accepts a complete user" do
    data = user_data(email_address: "newcomer@example.com")

    assert_nothing_raised do
      record_set(accounts(:acme)).check(from: zip_of("data/users/#{data["id"]}.json" => data.to_json))
    end
  end

  test "check rejects a user whose id doesn't match its file" do
    data = user_data(email_address: "newcomer@example.com")

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set(accounts(:acme)).check(from: zip_of("data/users/someone_else.json" => data.to_json))
    end
    assert_equal "User record ID mismatch: expected someone_else, got #{data["id"]}", error.message
  end

  test "check rejects a user missing fields" do
    data = user_data(email_address: "newcomer@example.com").except("role")
    path = "data/users/#{data["id"]}.json"

    error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
      record_set(accounts(:acme)).check(from: zip_of(path => data.to_json))
    end
    assert_equal "#{path} is missing required fields", error.message
  end

  private
    def record_set(account)
      Account::DataTransfer::UserRecordSet.new(account)
    end

    def user_data(email_address:)
      {
        "id" => ActiveRecord::Type::Uuid.generate, "email_address" => email_address, "name" => "Imported User",
        "role" => "member", "active" => true, "verified_at" => nil, "created_at" => Time.current, "updated_at" => Time.current
      }
    end
end
