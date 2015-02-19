require 'test_helper'

class BorrowDirectControllerTest < ActionController::TestCase
  # So-called "transactional fixtures" make all DB activity in a transaction,
  # which messes up Umlaut's background threading. 
  self.use_transactional_fixtures = false

  
  extend TestWithCassette

  test "400 on missing or bad parameters" do
    post :submit_request, :service_id => "no_such_service", :request_id => "1212"
    assert_failed_response "No such service for id `no_such_service`", 400

    post :submit_request, :service_id => "BorrowDirect", :request_id => "bad_id"
    assert_failed_response "No Request with id `bad_id`", 400
  end

  test "validation error on missing pickup_location" do
    # Missing pickup location
    request = submittable_request
    post :submit_request, :service_id => "BorrowDirect", :request_id => request.id
    assert_failed_response I18n.t("umlaut.services.borrow_direct_adaptor.bd_request_prompt.pickup_validation")
  end

  test "error on bad pickup location" do
    # Have pickup location, but no borrow_direct_request_prompt response found
    request = submittable_request
    post :submit_request, :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "foo"
    assert_failed_response "No existing bd_request_prompt response found for request #{request.id}"

    # borrow_direct_request_prompt response found, but pickup location
    # is not listed in it. 
    request = submittable_request
    request.add_service_response(
      :service_type_value => :bd_request_prompt,
      :service => ServiceStore.instantiate_service!("BorrowDirect", nil),
      :pickup_locations => %w{one two three}
    )
    post :submit_request, :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "foo"
    assert_failed_response "Pickup location `foo` not listed as acceptable in bd_request_prompt ServiceResponse"
  end

  test_with_cassette("good request", :controller) do
    request = submittable_request
    request.add_service_response(
      :service_type_value => :bd_request_prompt,
      :service => ServiceStore.instantiate_service!("BorrowDirect", nil),
      :pickup_locations => %w{one two three}
    )

    post :submit_request, :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "one"
    assert_assigns :request, :service, :service_id
    assert_response 303 # redirect

    assert_dispatched request, "BorrowDirect", DispatchedService::InProgress

    responses = assert_service_responses request, "BorrowDirect", :includes_type => [:bd_request_status]

    req_status = responses.find {|r| r.service_type_value_name == "bd_request_status"}
    assert_equal BorrowDirectController::InProgress, req_status.view_data[:status]

    # Wait on the bg_thread to complete using hacky just for testing
    # mechanism. This will make sure it's HTTP transaction is in the
    # VCR cassette, and also return us so when we access the menu
    # page again it should have a completed output. 
    @controller.instance_variable_get("@bg_thread").join
  end

  test_with_cassette("redirects to whitelisted url", :controller) do
    begin
      request = submittable_request
      request.add_service_response(
        :service_type_value => :bd_request_prompt,
        :service => ServiceStore.instantiate_service!("BorrowDirect", nil),
        :pickup_locations => %w{one two three}
      )

      @controller.umlaut_config.borrow_direct ||= {}
      @controller.umlaut_config.borrow_direct.redirect_whitelist = [
          "//example.org"
      ]

      post :submit_request, :redirect => "http://example.org", :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "one"
      assert_redirected_to "http://example.org"
    ensure
      @controller.umlaut_config.borrow_direct.delete(:redirect_whitelist)
    end
  end

  test_with_cassette("refuses to redirect to non whitelisted url", :controller) do
    request = submittable_request
    request.add_service_response(
      :service_type_value => :bd_request_prompt,
      :service => ServiceStore.instantiate_service!("BorrowDirect", nil),
      :pickup_locations => %w{one two three}
    )

    post :submit_request, :redirect => "http://example.org", :service_id => "BorrowDirect", :request_id => request.id, :pickup_location => "one"
    assert_redirected_to %r(http://test.host/)
  end


  def assert_failed_response(message, response_status = 303)
    assert_response response_status # redirect back to resolve menu usually

    if response_status == 303
      # make sure it has a ServiceResponse with bd_request_status and error
      responses = assert_service_responses(assigns[:request], "BorrowDirect", :includes_type => "bd_request_status")
      sresponse = responses.find {|sr| sr.service_type_value_name == "bd_request_status"}
      assert_includes sresponse.view_data[:error_user_message], message
    else
      assert_includes @response.body, message
    end
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
