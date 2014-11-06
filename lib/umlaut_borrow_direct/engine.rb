require 'umlaut'

module UmlautBorrowDirect
  class Engine < ::Rails::Engine
    engine_name "umlaut_borrow_direct"

    initializer "umlaut_borrow_direct.add_service_types" do |app|
      service_type_hash = Hash[UmlautBorrowDirect.service_type_values.collect {|v| [v, {}] }]
      ServiceTypeValue.merge_hash! service_type_hash
    end

    initializer "#{engine_name}.backtrace_cleaner", :before => "umlaut.backtrace_cleaner" do
      Umlaut::Engine.config.whitelisted_backtrace[self.root] = self.engine_name
    end

  end
end
