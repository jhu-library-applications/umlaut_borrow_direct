class BorrowDirectController < UmlautController
  before_filter :load_service_and_response


  # Will POST here as /borrow_direct/:service_id/:request_id
  #
  # Will return a 500 if service_id or service_response_id can't be found
  def submit_request    
    # mark the DispatchedService as InProgress again -- we do this
    # mainly so standard Umlaut will catch if it times out with no
    # request confirmation update, and mark it as errored appropriately. 
    @request.dispatched(@service, DispatchedService::InProgress)

    # redirect back to /resolve menu, for same object, add explicit request_id
    # in too. 
    redirect_to url_for_with_co({:controller => "resolve", "umlaut.request_id" => @request.id}, @request.to_context_object), :status => 303
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
      render :status => 400, :text => "No such service for id `#{params[:service_id]}`"
      return
    end

    @request = Request.where(:id => params[:request_id]).first
    if @request.nil?
      render :status => 400, :text => "No Request with id `#{params[:request_id]}`"
      return
    end

    if params[:pickup_location].blank?
      render :status => 400, :text => "Missing required pickup_location"
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
      render :status => 400, :text => "No existing bd_request_prompt response found for request #{@request.id}"
      return
    end
    unless request_prompt.view_data["pickup_locations"].include? params[:pickup_location]
      render :status => 400, :text => "Pickup location `#{params[:pickup_location]}` not listed as acceptable in bd_request_prompt ServiceResponse #{request_prompt.id}"
      return
    end

  end

end
