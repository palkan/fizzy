# typed: true

# @requires_ancestor: Account
module Account::Seedeable
  extend ActiveSupport::Concern

  #: () -> void
  def setup_customer_template
    account = self #: as Account
    Account::Seeder.new(account, users.admin.first).seed
  end
end
