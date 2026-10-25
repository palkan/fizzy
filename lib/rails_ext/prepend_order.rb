module ActiveRecordRelationPrependOrder
  # @type instance: ActiveRecord::Relation
  extend ActiveSupport::Concern

  included do
    # @type self: singleton(ActiveRecord::Relation)
    #: (*untyped) -> ActiveRecord::Relation
    def prepend_order(*args)
      new_orders = args.flatten.map { |arg| arg.is_a?(String) ? arg : arg.to_sql }

      spawn.tap do |relation|
        relation.order_values = new_orders + order_values
      end
    end
  end
end

ActiveRecord::Relation.include(ActiveRecordRelationPrependOrder)
ActiveRecord::AssociationRelation.include(ActiveRecordRelationPrependOrder)
