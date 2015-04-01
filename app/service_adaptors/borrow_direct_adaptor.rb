require 'borrow_direct'

# optional parameter http_timeout, in seconds, for HTTP with BD. BD can be _slow_. 
# default to 20 seconds. Much longer, you might start running into Umlaut's
# own global request processing timeouts. If timeout is reached, service
# should produce a URL linking into a DIY BD search, AND display an error. 
class BorrowDirectAdaptor < Service
  include MetadataHelper

  required_config_params :library_symbol, :find_item_patron_barcode, :html_query_base_url

  attr_accessor :library_symbol, :http_timeout, :use_bd_api

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
    @suppress_rfr_ids = ["info:sid/BD", "info:sid/BD-Unfilled"]

    # Should we use the api at all? Set to false to disable API
    # entirely, because you think it performs too crappily or
    # because it's not yet avail in production. 
    @use_bd_api = true

    super
  end

  def service_types_generated
    return [ServiceTypeValue[:bd_link_to_search], ServiceTypeValue[:bd_request_prompt], ServiceTypeValue[:bd_not_available], ServiceTypeValue[:bd_request_status]]
  end

  def appropriate_citation_type?(request)
    return ! title_is_serial?(request.referent)
  end

  # Make sure there are no hyphens, BD doesn't seem to like it
  def isbn(request)
    request.referent.isbn && request.referent.isbn.gsub('-', '')
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

    # Always add a manual link to search results
    make_link_to_search_response(request)

    if can_precheck_borrow_direct?(request)
      # pre-check it with BD api, this will take a while
      begin
        finditem = BorrowDirect::FindItem.new(@find_item_patron_barcode, @library_symbol)
        finditem.timeout = @http_timeout
        response = finditem.find(:isbn => isbn(request))

        # Log success if configured, used for looking at error rate
        bd_api_log(isbn(request), "FindItem", "SUCCESS", finditem.last_request_time)

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
        bd_api_log(isbn(request), "FindItem", e, finditem.last_request_time)

        # And mark it as an error so error message will be displayed. Let's
        # mark it a temporary error, so it'll be tried again later, it might
        # be a temporary problem on BD, esp timeout.         
        return request.dispatched(self, DispatchedService::FailedTemporary, e)
      end
    end

    return request.dispatched(self, true)
  end

  # Does Umlaut have info to think the item is locally available?
  # By default, check for Umlaut holding responses, but can
  # be customized with config. 
  def locally_available?(request)
    UmlautBorrowDirect.locally_available? request
  end

  # Right now, if and only if we have an ISBN and the API is enabled. 
  def can_precheck_borrow_direct?(request)
    return false unless @use_bd_api

    isbn(request).present?
  end

  def bd_api_log(isbn, action, result, timing)
    if result.kind_of? Exception
      result = "#{result.class}/#{result.message}"
      if result.respond_to?(:bd_code) && result.bd_code.present?
        result += "/#{result.bd_code}"
      end
    end

    if @bd_api_log_level
      @bd_api_logger.send(@bd_api_log_level, "BD API log\t#{action}\t#{result}\t#{timing.round(1) if timing}\tisbn=#{isbn}")
    end
  end

  def make_link_to_search_response(request)
    # We used to try and include ISBN in our query too, as (ISBN OR (author AND title))
    # But some BD z3950 endpoints can't handle this query (harvard apparently), and
    # it's just generally touchier. We'll just use author/title, keeping things
    # simple seems to the key to predictable BD results. 
    title  = raw_search_title(request.referent)
    author = get_search_creator(request.referent)

    url = BorrowDirect::GenerateQuery.new(@html_query_base_url).normalized_author_title_query(
      :title  => title,
      :author => author,
      :max_title_words => @limit_title_words
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