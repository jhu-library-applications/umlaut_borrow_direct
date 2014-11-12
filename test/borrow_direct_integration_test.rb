require 'test_helper'

# test actual generated view with a live HTTP request. 
# Requires properly configured service in dummy/config/umlaut_services.yml, 
# with (if re-recording cassettes) proper library symbol and barcode taken from ENV. 
#
# Couldn't get minitest/spec and vcr integration to work with IntegrationTest,
# so we're using test::unit style with umlaut's test_with_cassette. 
# https://github.com/metaskills/minitest-spec-rails/issues/54
class BorrowDirectIntegrationTest < ActionDispatch::IntegrationTest
  extend TestWithCassette

  @@requestable_isbn      = ENV['BD_REQUESTABLE_ISBN'] || '9789810743734'
  @@non_requestable_isbn  = ENV["BD_NON_REQUESTABLE_ISBN"] || '0109836413'

  # So-called "transactional fixtures" make all DB activity in a transaction,
  # which messes up Umlaut's background threading. 
  self.use_transactional_fixtures = false

    test "displays nothing for non-book-like items" do
      get "/resolve?genre=article&title=foo&author=bar"

      assert_no_service_errors

      assert_no_borrow_direct_section      
    end

    test "displays link without ISBN" do
      get "/resolve?genre=book&author=Smith&title=Some+Book"

      assert_no_service_errors

      assert_borrow_direct_section do      
        assert_select "a.response_link[href]", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.display_text")
        assert_select ".response_notes", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.notes")
      end
    end

    test_with_cassette("requestable ISBN displays form", :integration) do
      get "/resolve?isbn=#{@@requestable_isbn}"

      assert_no_service_errors

      assert_borrow_direct_section do
        assert_select ".borrow-direct-request-form" do |form_element|
          form_element = form_element.first

          assert_equal   "post", form_element["method"]          
          assert form_element["action"].present?

          assert_select "select[name=pickup_location]" do 
            assert_select "option:first-child", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_request_prompt.pickup_prompt")
          end
          assert_select "input[type=submit][value=?]", I18n.translate("umlaut.services.borrow_direct_adaptor.bd_request_prompt.request")
        end
      end
    end

    test_with_cassette("non-requestable ISBN displays unavailable message", :integration) do
      get "/resolve?isbn=#{@@non_requestable_isbn}"

      assert_no_service_errors

      assert_borrow_direct_section do
        assert_select ".umlaut-unavailable", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_not_available.display_text")
      end
    end

    test_with_cassette("error message displayed for dispatch error", :integration) do
      service = BorrowDirectAdaptor.new(
        "type" => "BorrowDirectAdaptor",
        "priority" => 1,
        "library_symbol" => "foo",
        "find_item_patron_barcode" => "bar",
        "html_query_base_url"      => "baz",
        "service_id" => "BorrowDirect"
      )    
      request = fake_umlaut_request("/resolve?genre=book&title=foo")
      request.dispatched(service, DispatchedService::FailedFatal)

      get "/resolve?umlaut.request_id=#{request.id}"

      assert_borrow_direct_section do |element|
        assert_select ".borrow-direct-error"
      end

    end

    test_with_cassette("BD timeout displays error with search link") do
      @test_html_query_base_url = "http://example.com/redirect"
      @service_config = {
        "type" => "BorrowDirectAdaptor",
        "priority" => 1,
        "library_symbol" => VCRFilter[:bd_library_symbol],
        "find_item_patron_barcode" => VCRFilter[:bd_patron],
        "html_query_base_url"      => @test_html_query_base_url,
        # small timeout to force error
        "http_timeout"             => 0.0001
      }
      @service_config_list = {'default' => {
        "services" => {
            "test_bd" => @service_config
          }
        }
      }

      with_service_config(@service_config_list) do
        get "/resolve?isbn=#{@@requestable_isbn}"
        assert_borrow_direct_section do |el|          
          # the error message
          assert_select ".borrow-direct-error"
          assert_select ".borrow-direct-error-info"
          # the link
          assert_select "a.response_link[href]", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.display_text")
          assert_select ".response_notes", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.notes")
        end
      end
    end



  def assert_no_service_errors
    # the containers are there either way, have to check for content
    assert_select ".umlaut-section.service_errors h5", :count => 0
  end

  def assert_no_borrow_direct_section
    assert_select ".umlaut-section.borrow_direct", :count => 0
  end

  def assert_borrow_direct_section
    section = assert_select ".umlaut-section.borrow_direct", :count => 1 do |element|
      assert_select ".section_heading h3", :text => I18n.t("umlaut.display_sections.borrow_direct.title")
      assert_select ".section_heading .section_prompt", :text => I18n.t("umlaut.display_sections.borrow_direct.prompt")

      yield(element) if block_given?
    end

    return section
  end

end