require "test_helper"

class Account::DataTransfer::EntropyRecordSetTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  test "import updates the period of a container that already has one" do
    account = accounts("37s")
    entropy = entropies(:writebook_board)
    data = entropy_data(account, container: boards(:writebook), period: 7.days)

    assert_no_difference -> { Entropy.count } do
      record_set(account).import(from: zip_of("data/entropies/#{data["id"]}.json" => data.to_json))
    end
    assert_equal 7.days.to_i, entropy.reload.auto_postpone_period
  end

  test "import adds the period of a container that has none" do
    account = accounts("37s")
    board = boards(:writebook)
    board.entropy.destroy!
    data = entropy_data(account, container: board, period: 7.days)

    assert_difference -> { Entropy.count }, +1 do
      record_set(account).import(from: zip_of("data/entropies/#{data["id"]}.json" => data.to_json))
    end
    assert_equal 7.days.to_i, Entropy.find_by(container: board).auto_postpone_period
  end

  private
    def record_set(account)
      Account::DataTransfer::EntropyRecordSet.new(account)
    end

    def entropy_data(account, container:, period:)
      {
        "id" => ActiveRecord::Type::Uuid.generate, "account_id" => account.id, "container_type" => container.class.name,
        "container_id" => container.id, "auto_postpone_period" => period.to_i, "created_at" => Time.current, "updated_at" => Time.current
      }
    end
end
