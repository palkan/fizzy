require "test_helper"

class Filter::ParamsTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "remembering equivalent filters" do
    assert_difference "Filter.count", +1 do
      filter = users(:david).filters.remember(sorted_by: "latest", assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])

      assert_changes "filter.reload.updated_at" do
        assert_equal filter, users(:david).filters.remember(tag_ids: [ tags(:mobile).id ], assignment_status: "unassigned")
      end
    end
  end

  test "remembering equivalent filters for different users" do
    assert_difference "Filter.count", +2 do
      users(:david).filters.remember(assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])
      users(:kevin).filters.remember(assignment_status: "unassigned", tag_ids: [ tags(:mobile).id ])
    end
  end

  test "turning into params" do
    filter = users(:david).filters.new sorted_by: "latest", tag_ids: "", assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ]
    expected = { assignee_ids: [ users(:jz).id ], board_ids: [ boards(:writebook).id ] }
    assert_equal expected, filter.as_params
  end

  test "turning every non-default field into params" do
    filter = users(:david).filters.new \
      indexed_by: "closed", sorted_by: "newest", creation: "thisweek", closure: "today", assignment_status: "unassigned",
      terms: [ "haggis" ], tag_ids: [ tags(:mobile).id ], board_ids: [ boards(:writebook).id ], card_ids: [ cards(:logo).id ],
      assignee_ids: [ users(:jz).id ], creator_ids: [ users(:kevin).id ], closer_ids: [ users(:david).id ]

    expected = {
      indexed_by: "closed", sorted_by: "newest", creation: "thisweek", closure: "today", assignment_status: "unassigned",
      terms: [ "haggis" ], tag_ids: [ tags(:mobile).id ], board_ids: [ boards(:writebook).id ], card_ids: [ cards(:logo).id ],
      assignee_ids: [ users(:jz).id ], creator_ids: [ users(:kevin).id ], closer_ids: [ users(:david).id ]
    }
    assert_equal expected, filter.as_params
  end

  test "params without one value of a list" do
    filter = users(:david).filters.new tag_ids: [ tags(:mobile).id, tags(:web).id ]

    assert_equal({ tag_ids: [ tags(:web).id ] }, filter.as_params_without(:tag_ids, tags(:mobile).id))
    assert_equal({}, users(:david).filters.new(tag_ids: [ tags(:mobile).id ]).as_params_without(:tag_ids, tags(:mobile).id))
  end

  test "params without a single value" do
    filter = users(:david).filters.new indexed_by: "closed", terms: [ "haggis" ]

    assert_equal({ terms: [ "haggis" ] }, filter.as_params_without(:indexed_by, "closed"))
    assert_equal filter.as_params, filter.as_params_without(:indexed_by, "stalled")
  end

  test "an unsaved filter has the digest it would be saved with" do
    filter = users(:david).filters.new tag_ids: [ tags(:mobile).id ]
    assert_equal Filter.digest_params(filter.as_params), filter.params_digest

    filter.save!
    assert_equal Filter.digest_params(filter.as_params), filter.reload.params_digest
  end

  test "check if a filter is used" do
    assert users(:david).filters.new(creator_ids: [ users(:david).id ]).used?
    assert_not users(:david).filters.new.used?

    assert users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?
    assert_not users(:david).filters.new(board_ids: [ boards(:writebook).id ]).used?(ignore_boards: true)
  end

  test "any one criterion makes a filter used" do
    criteria = {
      tag_ids: [ tags(:mobile).id ], assignee_ids: [ users(:jz).id ], creator_ids: [ users(:kevin).id ],
      closer_ids: [ users(:david).id ], terms: [ "haggis" ], card_ids: [ cards(:logo).id ], board_ids: [ boards(:writebook).id ],
      assignment_status: "unassigned", indexed_by: "closed", sorted_by: "newest"
    }

    criteria.each do |name, value|
      assert users(:david).filters.new(name => value).used?, "Expected a filter by #{name} to be used"
    end
  end
end
