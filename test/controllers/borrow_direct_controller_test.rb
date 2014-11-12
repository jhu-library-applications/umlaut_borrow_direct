require 'test_helper'

class BorrowDirectControllerTest < ActionController::TestCase
  test "500 on missing or bad parameters" do
     post :submit_request, :service_id => "no_such_service", :request_id => "1212"
     assert_failed_response "No such service for id `no_such_service`"

     post :submit_request, :service_id => "BorrowDirect", :request_id => "bad_id"
     assert_failed_response "No Request with id `bad_id`"

     # Missing pickup location
     request = submittable_request
     post :submit_request, :service_id => "BorrowDirect", :request_id => request.id
     assert_failed_response "Missing required pickup_location"
  end

  test "good request assigns ivars" do
    request = submittable_request

    post :submit_request, :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "foo"
    assert_response 200

    assert_assigns :request, :service, :service_id
  end


  def assert_failed_response(message)
     assert_response 400
     assert_includes message, @response.body
   end


  def assert_assigns(*ivar_names)
    ivar_names.each do |ivar_name|
      assert assigns(ivar_name), "Expected @#{ivar_name} to be assigned"
    end
  end

  def submittable_request
    fake_umlaut_request("/resolve?isbn=121212")
  end
end
