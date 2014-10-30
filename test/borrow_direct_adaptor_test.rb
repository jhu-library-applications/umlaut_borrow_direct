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
    @service_config = {
      "type" => "BorrowDirectAdaptor",
      "priority" => 1,
      "library_symbol" => VCRFilter[:bd_library_symbol],
      "find_item_patron_barcode" => VCRFilter[:bd_patron]
    }
    @service_config_list = {'default' => {
      "services" => {
          "test_bd" => @service_config
        }
      }
    }
    
    @service = BorrowDirectAdaptor.new(@service_config.merge("service_id" => "test_bd"))
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
    end
  end

  describe "with live connection to BD", :vcr do
    it "creates a request form for a requestable item" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=#{ENV['BD_REQUESTABLE_ISBN'] || '9789810743734'}")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_request_prompt)

        assert response.view_data["pickup_locations"].present?
      end
    end

    it "adds a bd_not_available for confirmed non-requestable item" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=#{ENV["BD_NON_REQUESTABLE_ISBN"] || '0109836413'}")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_not_available)
      end
    end

    it "adds a bd_not_available for an ISBN not in BD at all" do
      with_service_config(@service_config_list) do
        request = fake_umlaut_request("/resolve?isbn=000000000")

        @service.handle(request)

        assert_dispatched request, "test_bd"

        response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_not_available)
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

        assert_dispatched request, "test_bd"
        response = assert_service_responses(request, "test_bd", :number => 1, :includes_type => :bd_link_to_search)

        assert response.view_data["url"].present?
      end
    end

  end


end