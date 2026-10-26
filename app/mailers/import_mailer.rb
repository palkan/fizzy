# typed: true

class ImportMailer < ApplicationMailer
  #: (Identity, Account) -> void
  def completed(identity, account)
    @account = account
    mail to: identity.email_address, subject: "Your Fizzy account import is done"
  end

  #: (Account::Import) -> void
  def failed(import)
    @import = import
    mail to: import.identity.email_address, subject: "Your Fizzy account import failed"
  end
end
