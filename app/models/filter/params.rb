module Filter::Params
  # @type instance: Filter
  extend ActiveSupport::Concern

  PERMITTED_PARAMS = [
    :assignment_status,
    :indexed_by,
    :sorted_by,
    :creation,
    :closure,
    card_ids: [],
    column_ids: [],
    assignee_ids: [],
    creator_ids: [],
    closer_ids: [],
    board_ids: [],
    tag_ids: [],
    terms: []
  ] #: Array[Symbol | Hash[Symbol, Array[untyped]]]

  module ClassMethods
    # @type instance: singleton(Filter)
    #: (untyped) -> Filter?
    def find_by_params(params)
      find_by params_digest: digest_params(params)
    end

    #: (untyped) -> String
    def digest_params(params)
      Digest::MD5.hexdigest normalize_params(params).to_json
    end

    #: (untyped) -> Hash[untyped, untyped]
    def normalize_params(params)
      params
        .to_h
        .compact_blank
        .reject(&method(:default_value?))
        .collect { |name, value| [ name, value.is_a?(Array) ? value.collect(&:to_s) : value.to_s ] }
        .sort_by { |name, _| name.to_s }
        .to_h
    end
  end

  included do
    # @type self: singleton(Filter)
    before_save { self.params_digest = self.class.digest_params(as_params) }
  end

  #: (?ignore_boards: bool) -> bool
  def used?(ignore_boards: false)
    tags.any? || assignees.any? || creators.any? || closers.any? ||
      terms.any? || card_ids&.any? || (!ignore_boards && boards.present?) ||
      assignment_status.unassigned? || !indexed_by.all? || !sorted_by.latest?
  end

  # +as_params+ uses `resource#ids` instead of `#resource_ids`
  # because the latter won't work on unpersisted filters.
  #: () -> Hash[Symbol, untyped]
  def as_params
    @as_params ||= {
      indexed_by:        indexed_by,
      sorted_by:         sorted_by,
      creation:          creation,
      closure:           closure,
      assignment_status: assignment_status,
      terms:             terms,
      tag_ids:           tags.ids,
      board_ids:         boards.ids,
      card_ids:          card_ids,
      assignee_ids:      assignees.ids,
      creator_ids:       creators.ids,
      closer_ids:        closers.ids
    }.compact_blank.reject { |key, value| default_value?(key, value) }
  end

  #: (Symbol, untyped) -> Hash[Symbol, untyped]
  def as_params_without(key, value)
    as_params.dup.tap do |params|
      if params[key].is_a?(Array)
        params[key] = params[key] - [ value ]
        params.delete(key) if params[key].empty?
      elsif params[key] == value
        params.delete(key)
      end
    end
  end

  #: () -> String
  def params_digest
    super.presence || self.class.digest_params(as_params)
  end
end
