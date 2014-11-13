require 'test_helper'

class UmlautBorrowDirectTest < ActiveSupport::TestCase

  def test_custom_service_types_added  
    %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_status}.each do |v|
      assert ServiceTypeValue.find(v).present?
    end
  end

  def test_custom_service_types_labelled
    %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_status}.each do |v|
      st = ServiceTypeValue.find(v)

      I18n.locale = :en

      assert_equal "BorrowDirect Availability", st.display_name
    end
  end


end
