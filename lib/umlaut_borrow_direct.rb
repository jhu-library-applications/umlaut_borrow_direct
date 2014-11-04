require "umlaut_borrow_direct/engine"

module UmlautBorrowDirect

  def self.resolve_section_definition
    {
      :div_id     => "borrow_direct",
      :html_area  => :main,
      :partial    => "borrow_direct/resolve_section",
      #:visibility => :responses_exist,
      :service_type_values => %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_placed}
    }
  end

  # Array of strings of all service type value names UmlautBorrowDirect does. 
  def self.service_type_values
    %w{bd_link_to_search bd_request_prompt bd_not_available bd_request_placed}
  end

end
