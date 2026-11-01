require "test_helper"

class Account::DataTransfer::ManifestTest < ActiveSupport::TestCase
  setup do
    @manifest = Account::DataTransfer::Manifest.new(accounts("37s"))
  end

  test "goes through the account and its users first, and files last" do
    record_sets = []
    @manifest.each_record_set { record_sets << it }

    assert_kind_of Account::DataTransfer::AccountRecordSet, record_sets.first
    assert_kind_of Account::DataTransfer::UserRecordSet, record_sets.second
    assert_kind_of Account::DataTransfer::ActiveStorage::FileRecordSet, record_sets.last
    assert record_sets.all? { it.account == accounts("37s") }
  end

  test "resumes at a given model with where it left off" do
    yielded = []
    @manifest.each_record_set(start: [ "Card", "last-card-id" ]) { |record_set, last_id| yielded << [ record_set.model.name, last_id ] }

    assert_equal [ "Card", "last-card-id" ], yielded.first
    assert_equal "Comment", yielded.second.first
    assert_nil yielded.second.last
    assert_not_includes yielded.map(&:first), "Board"
  end

  test "lets every record set import any of the models it covers" do
    record_sets = []
    @manifest.each_record_set { record_sets << it }

    model_names = record_sets.filter_map { it.model&.name }
    assert_includes model_names, "Card"
    assert record_sets.all? { it.importable_model_names == model_names }
  end

  test "needs a block" do
    error = assert_raises(ArgumentError) { @manifest.each_record_set }
    assert_equal "No block given", error.message
  end
end
