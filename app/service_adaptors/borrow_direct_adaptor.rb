require 'borrow_direct'

class BorrowDirectAdaptor < Service
  include MetadataHelper

  required_config_params :library_symbol, :find_item_patron_barcode, :html_query_base_url

  def service_types_generated
    return [ServiceTypeValue[:bd_link_to_search], ServiceTypeValue[:bd_request_prompt], ServiceTypeValue[:bd_not_available], ServiceTypeValue[:bd_request_placed]]
  end

  def handle(request)
    if title_is_serial?(request.referent)
      # we do nothing if it looks like an article or journal title. 
      return request.dispatched(self, true)
    end

    if locally_available?(request)
      # We do nothing if it looks like it's locally available
      return request.dispatched(self, true)
    end

    if can_precheck_borrow_direct?(request)
      # pre-check it with BD api, this will take a while
      begin
        response = BorrowDirect::FindItem.new(@find_item_patron_barcode, @library_symbol).find(:isbn => request.referent.isbn)
        if response.requestable?
          # Mark it requestable!
          request.add_service_response( 
            :service=>self, 
            :display_text => "Choose your delivery location",
            :display_text_i18n => "bd_request_prompt.display_text",
            :service_type_value => :bd_request_prompt,
            :pickup_locations => response.pickup_locations)
        else
          request.add_service_response( 
            :service=>self, 
            :display_text => "This item is not currently available from BorrowDirect",
            :display_text_i18n => "bd_not_available.display_text", 
            :service_type_value => :bd_not_available)
        end
      rescue BorrowDirect::Error => e 
        # BD didn't let us check availability, log it and give them
        # a consolation direct link response
        Rails.logger.error("BorrowDirect returned error on FindItem, resorting to a bd_link_to_search response instead.\n   #{e.inspect}\n   #{request.inspect}")

        make_link_to_search_response(request)
      end
    else
      # If we can't pre-check, we return a link to search!
      make_link_to_search_response(request)
    end


    return request.dispatched(self, true)
  end

  # Not yet implemented, always returns false. May be implemented
  # with local custom subclass overrides?
  def locally_available?(request)
    return false
  end

  # Right now, if and only if we have an ISBN
  def can_precheck_borrow_direct?(request)
    request.referent.isbn.present?
  end

  def make_link_to_search_response(request)
    url = BorrowDirect::GenerateQuery.new(@html_query_base_url).best_known_item_query_url_with(
      :isbn   => request.referent.isbn,
      :title  => get_search_title(request.referent),
      :author => get_search_creator(request.referent)
    )

    request.add_service_response( 
      :service=>self, 
      :display_text => "Check BorrowDirect for availability",
      :display_text_i18n => "bd_link_to_search.display_text",
      :notes => "May be available in BorrowDirect",
      :notes_i18n => "bd_link_to_search.notes",
      :url => url, 
      :service_type_value => :bd_link_to_search)
  end

end