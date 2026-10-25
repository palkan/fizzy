module Filter::Fields
  # @type instance: Filter
  extend ActiveSupport::Concern

  INDEXES = %w[ all closed not_now stalled postponing_soon golden ]
  SORTED_BY = %w[ newest oldest latest ]

  delegate :default_value?, to: :class

  module ClassMethods
    # @type instance: singleton(Filter)
    #: () -> { indexed_by: String, sorted_by: String }
    def default_values
      { indexed_by: "all", sorted_by: "latest" }
    end

    #: (Symbol | String, untyped) -> bool
    def default_value?(key, value)
      default_values[key.to_sym].eql?(value)
    end

    #: (String) -> String
    def indexed_by_human_name(index)
      case index
      when "postponing_soon"
        "Closing soon"
      when "closed"
        "Done"
      when "all"
        "Open"
      else
        index.humanize
      end
    end
  end

  included do
    # @type self: singleton(Filter)
    store_accessor :fields, :assignment_status, :indexed_by, :sorted_by, :terms, :creation, :closure #: String?
    store_accessor :fields, :card_ids, :column_ids #: Array[String]?

    #: () -> (ActiveSupport::StringInquirer & Filter::_AssignmentStatus)
    def assignment_status
      super.to_s.inquiry #: ActiveSupport::StringInquirer & Filter::_AssignmentStatus
    end

    #: () -> (ActiveSupport::StringInquirer & Filter::_IndexedBy)
    def indexed_by
      (super || default_indexed_by).inquiry #: ActiveSupport::StringInquirer & Filter::_IndexedBy
    end

    #: () -> (ActiveSupport::StringInquirer & Filter::_SortedBy)
    def sorted_by
      (super || default_sorted_by).inquiry #: ActiveSupport::StringInquirer & Filter::_SortedBy
    end

    def creation_window
      TimeWindowParser.parse(creation)
    end

    def closure_window
      TimeWindowParser.parse(closure)
    end

    #: () -> Array[String]
    def terms
      Array(super)
    end

    #: (String | Array[String] | nil) -> void
    def terms=(value)
      super(Array(value).filter(&:present?))
    end

    #: () -> Array[String]
    def column_ids
      column_ids = super #: Array[String]?
      column_ids ? Array(column_ids).filter(&:present?).uniq : []
    end

    #: (String | Array[String] | nil) -> void
    def column_ids=(value)
      super(Array(value).filter(&:present?).uniq)
    end
  end

  #: (**untyped) -> Filter
  def with(**fields)
    creator.filters.from_params(as_params).tap do |filter|
      fields.each do |key, value|
        filter.public_send("#{key}=", value)
      end
    end
  end

  #: () -> String
  def default_indexed_by
    self.class.default_values[:indexed_by]
  end

  #: () -> bool
  def default_indexed_by?
    default_value?(:indexed_by, indexed_by)
  end

  #: () -> String
  def default_sorted_by
    self.class.default_values[:sorted_by]
  end

  #: () -> bool
  def default_sorted_by?
    default_value?(:sorted_by, sorted_by)
  end
end
