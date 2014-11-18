module UmlautBorrowDirect
  # Defines extra routing needed for this plugin. 
  #
  # A module that will be mixed into Umlaut::Routes, when we call
  # Umlaut::Routes.register_routes in an initializer here in our engine
  module RouteSet

    def borrow_direct
      add_routes do |options|
        post "borrow_direct/:service_id/:request_id" => "borrow_direct#submit_request", :as => "borrow_direct_submit"
      end
    end
  end

end