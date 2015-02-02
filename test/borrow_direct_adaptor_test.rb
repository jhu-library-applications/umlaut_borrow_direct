require 'test_helper'

# To run these tests without VCR cassette (or recording new ones), you need to
# define shell env:
#    BD_LIBRARY_SYMBOL: Your BD library symbol
#    BD_PATRON: A barcode of a patron in your library that can be used to auth with BD
#
# You MAY need to define, if the defaults aren't accurate for your library/patron:
#    BD_REQUESTABLE_ISBN: The ISBN of an item that BD will consider requestable
#       for your patron
#    BD_NON_REQUESTABLE_ISBN: The ISBN of an item that BD will not consider requestable
describe "BorrowDirectAdaptor" do

  before do
    @test_html_query_base_url = "http://example.com/redirect"
    @service_config = {
      "type" => "BorrowDirectAdaptor",
      "priority" => 1,
      "library_symbol" => VCRFilter[:bd_library_symbol],
      "find_item_patron_barcode" => VCRFilter[:bd_patron],
      "html_query_base_url"      => @test_html_query_base_url
    }
    @service_config_list = {'default' => {
      "services" => {
          "test_bd" => @service_config,
          "test_holding" => {"type" => "DummyService", "priority" => 1}
        }
      }
    }
    
    @service = BorrowDirectAdaptor.new(@service_config.merge("service_id" => "test_bd"))
  end

  it "truncates long titles in search links" do
    with_service_config(@service_config_list) do
      request = fake_umlaut_request("resolve?title=Modern+agriculture%2C+based+on+%22Essentials+of+the+new+agriculture%22+by+Henry+Jackson+Waters%2C&aulast=Grimes")
      @service.make_link_to_search_response(request)

      response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_link_to_search)

      assert response.view_data[:url].present?
      url = response.view_data[:url]

      params = CGI.parse(URI.parse(url).query)

      bd_query = params["query"].first

      clauses = bd_query.split(" and ")

      assert(clauses.any? {|c| c == 'au="Grimes"'}, "Includes author clause")
      assert(clauses.any? {|c| c == 'ti="modern agriculture based on essentials"'}, "Includes title clause")
    end
  end

  it "does nothing for a non-book-like object" do
    request = fake_umlaut_request("resolve?sid=google&auinit=RD&aulast=Kaplan&atitle=The+coming+anarchy&title=The+Atlantic+monthly&volume=273&issue=2&date=1994&spage=44&issn=1072-7825")

    @service.handle(request)

    dispatched = request.dispatched_services.to_a.find {|ds| ds.service_id == "test_bd"}

    assert dispatched.present?
    assert_equal DispatchedService::Successful, dispatched.status

    assert_empty request.service_responses
  end

  it "creates a search for a book without ISBN" do
    with_service_config(@service_config_list) do
      request = fake_umlaut_request("/resolve?sid=google&auinit=EH&aulast=Lenneberg&title=Biological+foundations+of+language&genre=book&date=1967")

      @service.handle(request)

      assert_dispatched request, "test_bd"

      response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_link_to_search)

      assert response.view_data["url"].present?
      assert response.view_data["url"].start_with? @test_html_query_base_url
    end
  end

  describe "for local availability" do
    before do
      @available_status = UmlautController.umlaut_config.holdings.available_statuses.first
    end

    it "suppresses when :holding present with available status" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?title=title&author=au")
        request.add_service_response(
          :service => DummyService.new("service_id" => "test_holding", "priority" => 1),
          :service_type_value => :holding,
          :status => @available_status
        )

        @service.handle(request)

        assert_dispatched request, "test_bd"

        assert_service_responses(request, "test_bd", :number => 0)
      end
    end

    it "does not suppress for :holding with MatchUnsure" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?title=title&author=au")
        request.add_service_response(
          :service => DummyService.new("service_id" => "test_holding", "priority" => 1),
          :service_type_value => :holding,
          :match_reliability => ServiceResponse::MatchUnsure,
          :status => @available_status
        )

        @service.handle(request)

        assert_dispatched request, "test_bd"

        assert_service_responses(request, "test_bd", :number => 1)
      end
    end

    it "does not suppress for holding without available status" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?title=title&author=au")
        request.add_service_response(
          :service => DummyService.new("service_id" => "test_holding", "priority" => 1),
          :service_type_value => :holding,
          :status => "Checked out really not available can't get it"
        )

        @service.handle(request)

        assert_dispatched request, "test_bd"

        assert_service_responses(request, "test_bd", :number => 1)
      end

    end

    describe "with custom local avail check" do
      before do
        UmlautController.umlaut_config.borrow_direct ||= {}

        @previous_local_availability_check = UmlautController.umlaut_config.borrow_direct.local_availability_check

        UmlautController.umlaut_config.borrow_direct.local_availability_check = proc do |request, service|
          false
        end        
      end

      after do
        UmlautController.umlaut_config.borrow_direct.local_availability_check = @previous_local_availability_check        
      end

      it "uses custom local avail check" do      
        with_service_config(@service_config_list) do
          request = fake_umlaut_request("/resolve?title=title&author=au")
          request.add_service_response(
            :service => DummyService.new("service_id" => "test_holding", "priority" => 1),
            :service_type_value => :holding
          )

          @service.handle(request)

          assert_dispatched request, "test_bd"

          assert_service_responses(request, "test_bd", :number => 1)         
        end
      end
    end

  end

  describe "with live connection to BD", :vcr do
    it "creates a request form for a requestable item" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=#{ENV['BD_REQUESTABLE_ISBN'] || '9789810743734'}")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        responses = assert_service_responses(request, "test_bd", :number => 2, :includes_type => [:bd_link_to_search, :bd_request_prompt])

        prompt_response = responses.find {|r| r.service_type_value_name == "bd_request_prompt"}
        assert prompt_response.view_data["pickup_locations"].present?
      end
    end

    it "adds a bd_not_available for confirmed non-requestable item" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=#{ENV["BD_NON_REQUESTABLE_ISBN"] || '0109836413'}")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        response = assert_service_responses(request, "test_bd", :number => 2, :includes_type => [:bd_not_available, :bd_link_to_search])
      end
    end

    it "adds a bd_not_available for an ISBN not in BD at all" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=000000000")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        response = assert_service_responses(request, "test_bd", :number => 2, :includes_type => [:bd_link_to_search, :bd_not_available])
      end
    end

    it "returns a link when BD returns an error" do
      # Trigger a BD error by giving it a bad library_symbol
      # We want an error logged, and a link result supplied instead. 

      @service = BorrowDirectAdaptor.new(
        @service_config.merge("library_symbol" => "BAD_SYMBOL", "service_id" => "test_bd")
      )      

      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=#{ENV['BD_REQUESTABLE_ISBN'] || '9789810743734'}")

        @service.handle(request)

        assert_dispatched request, "test_bd", DispatchedService::FailedTemporary
        response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_link_to_search)

        assert response.view_data["url"].present?
      end
    end

  end


end