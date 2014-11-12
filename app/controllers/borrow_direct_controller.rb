class BorrowDirectController < ApplicationController
  before_filter :load_service_and_response


  # Will POST here as /borrow_direct/:service_id/:request_id
  #
  # Will return a 500 if service_id or service_response_id can't be found
  def submit_request    
    # mark the DispatchedService as InProgress again, to trigger the spinner
    @service_response.request.dispatched(@service, DispatchedService::InProgress)
  end

  protected
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
    if @service_response.nil?
      render :status => 400, :text => "No ServiceResponse with id `params[:service_response_id]`"
      return
    end
  end

end
