module Account::Seedeable
  # @type instance: Account
  extend ActiveSupport::Concern

  #: () -> void
  def setup_customer_template
    Account::Seeder.new(self, users.admin.first).seed
  end
end
