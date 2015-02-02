require 'borrow_direct'

# optional parameter http_timeout, in seconds, for HTTP with BD. BD can be _slow_. 
# default to 20 seconds. Much longer, you might start running into Umlaut's
# own global request processing timeouts. If timeout is reached, service
# should produce a URL linking into a DIY BD search, AND display an error. 
class BorrowDirectAdaptor < Service
  include MetadataHelper

  required_config_params :library_symbol, :find_item_patron_barcode, :html_query_base_url

  attr_accessor :library_symbol

  def initialize(config)
    # testing shows truncating titles to 5 words results in fewer
    # false negatives seemingly without significant false positives. 
    # but you can set to nil/empty to disable truncation, or
    # set to a different number. 
    @limit_title_words = 5 
    @display_name = "BorrowDirect"
    @http_timeout = 20

    # Log BD API calls to logger -- defaults to Rails.logger
    @bd_api_logger = Rails.logger

    # set to 'warn', 'info', 'debug', etc to turn on logging
    # of succesful FindItem api requests. Useful for looking at error rate. 
    # nil means don't log. 
    @bd_api_logger_level = nil
    # Abort for these rfr_id's -- keep from searching BD when
    # we came from BD. 
    @suppress_rfr_ids = ["info:sid/BD"]
    super
  end

  def service_types_generated
    return [ServiceTypeValue[:bd_link_to_search], ServiceTypeValue[:bd_request_prompt], ServiceTypeValue[:bd_not_available], ServiceTypeValue[:bd_request_status]]
  end

  def appropriate_citation_type?(request)
    return ! title_is_serial?(request.referent)
  end

  def handle(request)
    if request.referrer_id && @suppress_rfr_ids.include?(request.referrer_id)
      return request.dispatched(self, true)
    end

    if ! appropriate_citation_type?(request)
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
        finditem = BorrowDirect::FindItem.new(@find_item_patron_barcode, @library_symbol)
        finditem.timeout = @http_timeout
        response = finditem.find(:isbn => request.referent.isbn)

        # Log success if configured, used for looking at error rate
        bd_api_log(request.referent.isbn, "FindItem", "SUCCESS", finditem.last_request_time)

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
        msg =  "BorrowDirect returned error on FindItem, resorting to a bd_link_to_search response instead.\n"
        msg += "    * Returned error: #{e.inspect}\n"
        msg += "    * BD url: #{finditem.last_request_uri}\n"
        msg += "    * Posted with json payload: #{finditem.last_request_json}\n"
        Rails.logger.error(msg)

        # Special BD error log if configured
        bd_api_log(request.referent.isbn, "FindItem", e.class, finditem.last_request_time)

        make_link_to_search_response(request)
        # And mark it as an error so error message will be displayed. Let's
        # mark it a temporary error, so it'll be tried again later, it might
        # be a temporary problem on BD, esp timeout.         
        return request.dispatched(self, DispatchedService::FailedTemporary, e)
      end
    else
      # If we can't pre-check, we return a link to search!
      make_link_to_search_response(request)
    end

    return request.dispatched(self, true)
  end

  # Does Umlaut have info to think the item is locally available?
  # By default, check for Umlaut holding responses, but can
  # be customized with config. 
  def locally_available?(request)
    UmlautBorrowDirect.locally_available? request
  end

  # Right now, if and only if we have an ISBN
  def can_precheck_borrow_direct?(request)
    request.referent.isbn.present?
  end

  def bd_api_log(isbn, action, result, timing)
    if @bd_api_log_level
      @bd_api_logger.send(@bd_api_log_level, "BD API log\t#{action}\t#{result}\t#{timing.round(1)}\tisbn=#{isbn}")
    end
  end

  def make_link_to_search_response(request)
    title = get_search_title(request.referent)

    unless @limit_title_words.blank? || title.blank?
      if title.index(/((.+?[ ,.:\;]+){5})/)
        title = title.slice(0, $1.length).gsub(/[ ,.:\;]+$/, '')
      end
    end

    url = BorrowDirect::GenerateQuery.new(@html_query_base_url).best_known_item_query_url_with(
      :isbn   => request.referent.isbn,
      :title  => title,
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