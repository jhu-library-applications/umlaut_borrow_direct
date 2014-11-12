require 'test_helper'

class BorrowDirectControllerTest < ActionController::TestCase
  test "500 on missing or bad parameters" do
     post :submit_request, :service_id => "no_such_service", :request_id => "1212"
     assert_response 400

     post :submit_request, :service_id => "BorrowDirect", :request_id => "bad_id"
     assert_response 400
  end

end
