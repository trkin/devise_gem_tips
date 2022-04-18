require 'application_system_test_case'

class SignUpTest < ApplicationSystemTestCase
  test 'sign up' do
    visit root_path
    click_on 'Login'
    click_on "Sign up"
    fill_in 'Email', with: "new@email.com"
    fill_in 'Password', with: 'password'
    fill_in 'Password confirmation', with: 'password'
    click_on 'Sign up'
    assert_notice_message "Welcome! You have signed up successfully."
    user = User.find_by email: "new@email.com"
    assert user.valid_password? 'password'
  end
end
