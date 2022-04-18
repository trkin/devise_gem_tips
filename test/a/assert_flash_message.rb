class ActionDispatch::IntegrationTest
  # assert_flash_message
  def assert_alert_message(text)
    assert_select '[data-test=alert]', text
  end

  def assert_notice_message(text)
    assert_select '[data-test=notice]', text
  end
end

class ActionDispatch::SystemTestCase
  def assert_alert_message(text)
    assert_selector '[data-test=alert]', text: text
  end

  def assert_notice_message(text)
    assert_selector '[data-test=notice]', text: text
  end
end
