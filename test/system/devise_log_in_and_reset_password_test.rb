require 'application_system_test_case'

class DeviseLogInResetPasswordTest < ApplicationSystemTestCase
  test 'log in' do
    user = users(:user)
    visit root_path
    click_on 'Login'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'wrong'
    click_on 'Log in'

    assert_alert_message 'Invalid Email or password.'

    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'
    click_on 'Log in'

    assert_notice_message "Signed in successfully."
    assert_selector '[data-test=current-user-email]', text: user.email
  end

  test 'forgot password with email' do
    user = users(:user)
    visit root_path
    click_on 'Login'
    click_on "Forgot your password?"
    fill_in 'Email', with: user.email
    click_on 'Send me reset password instructions'

    assert_notice_message 'You will receive an email with instructions on how to reset your password in a few minutes.'
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    password_link = mail.body.encoded.match(
      /(http:\S*)".*>Change my password/
    )[1]
    visit password_link

    fill_in 'New password', with: 'new_pass'
    fill_in 'Confirm new password', with: 'new_pass'
    click_on 'Change my password'

    user = User.find_by(email: user.email)
    assert user.valid_password? 'new_pass'
  end

  test 'resend confirmation instructions' do
    user = users(:user)
    user.update! confirmed_at: nil

    visit root_path
    click_on 'Login'
    click_on 'Forgot Password?'
    click_on "Didn't receive confirmation instructions?"
    fill_in 'Enter Email', with: user.email
    click_on 'Resend confirmation instructions'

    assert_notice_message 'You will receive an email with instructions for how to confirm your email address in a few minutes.'
    mail = ActionMailer::Base.deliveries.last
    assert_equal [user.email], mail.to
    confirm_link = mail.body.encoded.match(
      /(http:\S*)".*>Confirm My Account/
    )[1]
    visit confirm_link

    assert_notice_message 'Your email address has been successfully confirmed.'
    user.reload
    assert user.confirmed_at
  end
end
