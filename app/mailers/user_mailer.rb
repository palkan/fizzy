class UserMailer < ApplicationMailer
  #: (email_address: String, token: String, user: User) -> void
  def email_change_confirmation(email_address:, token:, user:)
    @token = token
    @user = user
    mail to: email_address, subject: "Confirm your new email address"
  end
end
