require 'uri'
require 'umlaut_borrow_direct/url_whitelister'

# Superclass for actual BorrowDirectController, which will usually
# be implemented in local app, with an override of #current_user_barcode
# that provides some local auth system to figure out current barcode
# to make a request with. 
module UmlautBorrowDirect
  class ControllerImplementation < UmlautController
    before_filter :load_service_and_response

    # Status codes used in ServiceResponses of type bd_request_status
    Successful       = "successful"
    InProgress      = "in_progress"
    ValidationError = "validation_error" # user input error
    Error           = "error" # system error

    # Will http GET to here as /borrow_direct/:service_id/:request_id
    # (really should be POST, but Shibboleth and other SSO protection
    # have a problem with that, bah. The fact that we are immediately redirecting
    # should keep it from being as big a deal.)
    #
    # Will return a 500 if service_id or service_response_id can't be found
    def submit_request    
      # mark the DispatchedService as InProgress again -- we do this
      # mainly so standard Umlaut will catch if it times out with no
      # request confirmation update, and mark it as errored appropriately. 
      @request.dispatched(@service, DispatchedService::InProgress)

      # add a bd_request_status object as a place to mark that we are in progress
      # specifically with placing a request, and blanking out any previous
      # errors from existing one. 
      set_status_response(
        :status => InProgress,
        :error_user_message => ""
      )

      # We need to have a barcode to make a request. Custom sub-class must
      # supply. 

      # We're gonna kick off the actual request submission in a bg thread,
      # cause it's so damn slow. Yeah, if the process dies in the middle, we might
      # lose it. Umlaut will notice after a timeout and display error. 
      # Saving the @bg_thread only so in testing we can wait on it. 
      @bg_thread = Thread.new(@request, @service, @request.referent.isbn) do |request, service, isbn|
        begin
          ActiveRecord::Base.forbid_implicit_checkout_for_thread!

          requester = BorrowDirect::RequestItem.new(self.patron_barcode, service.library_symbol)
          requester.timeout = @service.http_timeout
          request_number = requester.make_request!(params[:pickup_location], :isbn => isbn)

          ActiveRecord::Base.connection_pool.with_connection do
            service.bd_api_log(isbn, "RequestItem", "SUCCESS", requester.last_request_time)

            request.dispatched(service, DispatchedService::Successful)
            set_status_response({:status => Successful, :request_number => request_number }, request)
          end

        rescue StandardError => e
          # If it was an AR error in the first place, forget trying to record
          # it. 
          if e.kind_of?(ActiveRecord::ActiveRecordError)
            raise e
          end

          ActiveRecord::Base.connection_pool.with_connection do
            Rails.logger.error("BorrowDirect: Error placing request:  #{e.class} #{e.message}. Backtrace:\n  #{Umlaut::Util.clean_backtrace(e).join("\n  ")}\n")

            request.dispatched(service, DispatchedService::FailedFatal, e)

            status_response_data = {:status => Error}
            status_response_data[:error_user_message] = e.message if e.kind_of? UserReportableError

            set_status_response(status_response_data, request)

            if service
              service.bd_api_log(isbn, "RequestItem", e, (requester.last_request_time if requester))
            end


            # In testing, we kinda wanna re-raise this guy
            raise e if defined?(VCR::Errors::UnhandledHTTPRequestError) && e.kind_of?(VCR::Errors::UnhandledHTTPRequestError)
          end
        end
      end

      redirect_back_to_source
    end

    protected

    # Loads things from ID's giving in params, AND makes sure
    # all pre-reqs are made for actually submitting the request, and
    # returns and records an error if not. 
    def load_service_and_response
      @service_id = params[:service_id]

      begin
        @service = ServiceStore.instantiate_service!(@service_id, nil) if @service_id
      rescue ServiceStore::NoSuchService => e
      end

      if @service.nil?
        register_error "No such service for id `#{params[:service_id]}`"
        return
      end

      @request = Request.where(:id => params[:request_id]).first
      if @request.nil?
        register_error "No Request with id `#{params[:request_id]}`"
        return
      end

      if params[:pickup_location].blank?
        register_error I18n.t("umlaut.services.borrow_direct_adaptor.bd_request_prompt.pickup_validation"), ValidationError
        return
      end

      # Okay, we insist on there being an existing bd_request_prompt ServiceResponse,
      # and on the pickup location matching one of it's pickup locations. BD
      # itself does no validation of pickup_location (unclear what happens when you send
      # a bad pickup location), so we've got to be as careful as we can be. 
      request_prompt = @request.service_responses.to_a.find do |sr|
        sr.service_id == @service_id &&
        sr.service_type_value_name == "bd_request_prompt"
      end
      if request_prompt.nil?
        register_error "No existing bd_request_prompt response found for request #{@request.id}"
        return
      end
      unless request_prompt.view_data["pickup_locations"].include? params[:pickup_location]
        register_error "Pickup location `#{params[:pickup_location]}` not listed as acceptable in bd_request_prompt ServiceResponse #{request_prompt.id}"
        return
      end
    end

    # Redirects back to Umlaut menu, or to redirect URL if given and whitelisted,
    # or in some cases displays a bad error for whitelist error. 
    def redirect_back_to_source
      # If we've been requested to do so, redirect back to an external whitelisted service
      if (redirect_url = params["redirect"]) && redirect_url.present?
        if UmlautBorrowDirect::UrlWhitelister.new(self.umlaut_config.lookup!("borrow_direct.redirect_whitelist", [])).whitelisted?(redirect_url)
          redirect_to redirect_url
          return
        else
          # We used to redirect to plain umlaut page on URL unallowed by whitelist,
          # but that made debugging a confusing situation even harder. Just error
          # message it. 
          error_msg = "Error: UmlautBorrowDirect Controller: Ignoring redirect URL which does not match whitelist: #{redirect_url}"
          logger.warn(error_msg)
          render :status => 403, :text => error_msg
          return
        end
      end

      # redirect back to /resolve menu, for same object, add explicit request_id
      # in too. 
      redirect_to_resolve_menu
    end

    # error_type defaults to Error, but can also be ValidationError
    def register_error(msg, error_type = Error)
      if error_type == Error
        Rails.logger.error("BorrowDirectController: #{msg}")
      end

      if @request && @service
        set_status_response(
          :status => error_type,
          :error_user_message => msg
        )
      end

      # Redirect back to menu page
      if @request
        redirect_back_to_source
      else
        render :status => 400, :text => msg
      end
    end

    def set_status_response(properties, request = @request)
      # do we already have one, or should we create a new one?
      if bd_status = @request.get_service_type(:bd_request_status).first
        bd_status.take_key_values(properties)
        bd_status.save!
      else
        properties = properties.merge(
          :service            => @service,
          :service_type_value => :bd_request_status
        )  
        @request.add_service_response(properties)
      end

    end

    

    def redirect_to_resolve_menu
      redirect_to url_for_with_co({:controller => "resolve", "umlaut.request_id" => @request.id}, @request.to_context_object), :status => 303
    end

    # Should be overridden locally
    def patron_barcode
      raise StandardError.new("Developers must override patron_barcode locally to return authorized patron barcode.")
    end

    # Raise one of these with a message that should be shown to the user,
    # if you want an error message shown to the user. 
    class UserReportableError < StandardError ; end


  end
end