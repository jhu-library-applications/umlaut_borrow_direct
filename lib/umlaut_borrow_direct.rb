require "umlaut_borrow_direct/engine"

module UmlautBorrowDirect

  DefaultLocalAvailabilityCheck = proc do |request, service|
    request.get_service_type(:holding).find do |sr| 
      UmlautController.umlaut_config.holdings.available_statuses.include?(sr.view_data[:status]) &&
      sr.view_data[:match_reliability] != ServiceResponse::MatchUnsure 
    end.present?
  end

  # A custom lambda for visibility of our section. 
  # We want it to be visible if the service is still in progress,
  # or if it's finished with ServiceResponses generated, OR
  # if it's finished in an error state. 
  # Another way to say this, the section will NOT be visible when
  # the service has finished, without generating responses, or errors. 
  #
  # Oh, and don't show it at all unless citation does not pass
  # MetadataHelper.title_is_serial?. If we don't think it's a serial,
  # it's not appropriate for BD and no results will be shown, don't show
  # spinner either. 
  #
  # We took the Umlaut SectionRenderer visibility logic for :in_progress,
  # and added a condition for error state
  SectionVisibilityLogic = proc do |section_renderer|
      (! MetadataHelper.title_is_serial?(section_renderer.request.referent)) &&
        # IF we believe it's locally available, the adaptor is going to bail
        # anyway, but there can be a lag time waiting for it, let's recognize
        # and hide our section. 
      (! UmlautBorrowDirect.locally_available? section_renderer.request) &&
      (
        (! section_renderer.responses_empty?) || 
        section_renderer.services_in_progress? ||
        section_renderer.request.dispatch_objects_with(
          :service_type_values => UmlautBorrowDirect.service_type_values
        ).find_all {|ds| ds.failed? }.present?
      )
    end


  def self.resolve_section_definition
    {
      :div_id     => "borrow_direct",
      :html_area  => :main,
      :partial    => "borrow_direct/resolve_section",
      :visibility => SectionVisibilityLogic,
      :service_type_values => self.service_type_values,
      :show_spinner => false # we do our own
    }
  end

  # In a local app UmlautController:
  #     umlaut_config do
  #        add_section_highlights_filter! UmlautBorrowDirect.section_highlights_filter
  #
  # Applies some default rules for white-background-highlighting
  # of the borrow_direct section. 
  def self.section_highlights_filter
    proc {|umlaut_request, sections|
        # If it's not locally available, remove highlight from 'holding' --
        # will remove highlights for checked out material for instance. 
        # And add in document_delivery, although future lines may remove it again
        # if BD is available.
        if sections.include?("holding") && ! self.locally_available?(umlaut_request)
          sections.delete("holding")
          sections << "document_delivery"
        end


        # highlight BD section and NOT document_delivery if BD section is present
        if ( umlaut_request.get_service_type("bd_link_to_search").present? || 
             umlaut_request.get_service_type("bd_request_prompt").present? )
          sections.delete("document_delivery")
          sections << "borrow_direct"          
        end


        # If request is in progress or succesful, highlight it and not docdel. 
        if umlaut_request.get_service_type("bd_request_status").present?
          response = umlaut_request.get_service_type("bd_request_status").first
          if [ BorrowDirectController::InProgress, 
               BorrowDirectController::Successful].include? response.view_data[:status]
            sections.delete("document_delivery")
            sections << "borrow_direct" 
          elsif BorrowDirectController::Error == response.view_data[:status]
            sections.delete("document_delivery")
            sections << "borrow_direct" 
          end
        end
        
        sections.uniq!
      }
  end

  def self.locally_available?(request)
    aProc = UmlautController.umlaut_config.lookup!("borrow_direct.local_availability_check") || DefaultLocalAvailabilityCheck
    return aProc.call(request, self)
  end

  # Array of strings of all service type value names UmlautBorrowDirect does. 
  def self.service_type_values
    %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_status}
  end

end
