require 'umlaut'
require 'umlaut_borrow_direct/route_set'

module UmlautBorrowDirect
  class Engine < ::Rails::Engine
    engine_name "umlaut_borrow_direct"

    # Post is definitely more appropriate, but doens't work with
    # Shibboleth (and maybe other SSO) protection. Bah. We make
    # it a config variable, if :post doesn't conflict with your infrastructure,
    # you could try it.
    config.http_submit_method = :get

    initializer "umlaut_borrow_direct.add_service_types" do |app|
      require 'service_type_value'
      service_type_hash = Hash[UmlautBorrowDirect.service_type_values.collect {|v| [v, {}] }]
      ServiceTypeValue.merge_hash! service_type_hash
    end

    initializer "umlaut_borrow_direct.backtrace_cleaner", :before => "umlaut.backtrace_cleaner" do
      Umlaut::Engine.config.whitelisted_backtrace[self.root] = self.engine_name
    end

    initializer "umlaut_borrow_direct.routing" do
      Umlaut::Routes.register_routes( UmlautBorrowDirect::RouteSet )
    end

  initializer "umlaut_borrow_direct.set_api_base" do
    # We just set the default api_base in production, hopefully
    # that won't cause any problems, local app could do something different
    # in it's own initializer I think.
    if Rails.env.production?
      require 'borrow_direct'
      BorrowDirect::Defaults.api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
    end
  end

  end
end
