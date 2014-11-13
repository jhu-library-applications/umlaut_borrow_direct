require "umlaut_borrow_direct/engine"

module UmlautBorrowDirect

  def self.resolve_section_definition
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
    visibility_logic = lambda do |section_renderer|
      (! MetadataHelper.title_is_serial?(section_renderer.request.referent)) &&
      (
        (! section_renderer.responses_empty?) || 
        section_renderer.services_in_progress? ||
        section_renderer.request.dispatch_objects_with(
          :service_type_values => UmlautBorrowDirect.service_type_values
        ).find_all {|ds| ds.failed? }.present?
      )
    end

    {
      :div_id     => "borrow_direct",
      :html_area  => :main,
      :partial    => "borrow_direct/resolve_section",
      :visibility => visibility_logic,
      :service_type_values => self.service_type_values,
      :show_spinner => false # we do our own
    }
  end

  # Array of strings of all service type value names UmlautBorrowDirect does. 
  def self.service_type_values
    %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_status}
  end

end
