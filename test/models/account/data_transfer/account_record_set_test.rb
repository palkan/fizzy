require "test_helper"

class Account::DataTransfer::AccountRecordSetTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  test "export writes the account with its join code" do
    zip = written_zip { |writer| record_set(accounts("37s")).export(to: writer) }
    data = JSON.parse(zip.read("data/account.json"))

    assert_equal "37signals", data["name"]
    assert_equal({ "code" => "37S0-5678-9XYZ", "usage_count" => 0, "usage_limit" => 10 }, data["join_code"].slice("code", "usage_count", "usage_limit"))
  end

  test "import takes the account's name, card count and join code" do
    account = accounts(:initech)

    record_set(account).import(from: zip_of("data/account.json" => account_data.to_json))

    account.reload
    assert_equal "Imported Inc", account.name
    assert_equal 42, account.cards_count
    assert_equal [ "IMPO-RTED-CODE", 3, 7 ], [ account.join_code.code, account.join_code.usage_count, account.join_code.usage_limit ]
  end

  test "import without a card count starts counting from zero" do
    account = accounts("37s")

    record_set(account).import(from: zip_of("data/account.json" => account_data.except("cards_count").to_json))

    assert_equal 0, account.reload.cards_count
  end

  test "check accepts a complete account" do
    assert_nothing_raised do
      record_set(accounts(:initech)).check(from: zip_of("data/account.json" => account_data.to_json))
    end
  end

  test "check rejects an account missing its name" do
    assert_check_error "Account record missing required fields", account_data.except("name")
  end

  test "check rejects an account missing its join code" do
    assert_check_error "Account record missing required fields", account_data.except("join_code")
  end

  test "check rejects a join code that isn't an object" do
    assert_check_error "'join_code' field must be a JSON object", account_data.merge("join_code" => "IMPO-RTED-CODE")
  end

  test "check rejects a join code missing its usage" do
    assert_check_error "'join_code' field missing required keys", account_data.merge("join_code" => { "code" => "IMPO-RTED-CODE" })
  end

  private
    def record_set(account)
      Account::DataTransfer::AccountRecordSet.new(account)
    end

    def account_data
      { "name" => "Imported Inc", "cards_count" => 42, "join_code" => { "code" => "IMPO-RTED-CODE", "usage_count" => 3, "usage_limit" => 7 } }
    end

    def assert_check_error(message, data)
      error = assert_raises(Account::DataTransfer::RecordSet::IntegrityError) do
        record_set(accounts(:initech)).check(from: zip_of("data/account.json" => data.to_json))
      end
      assert_equal message, error.message
    end
end
