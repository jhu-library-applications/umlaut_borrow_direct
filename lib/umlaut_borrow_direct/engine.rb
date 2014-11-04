module UmlautBorrowDirect
  class Engine < ::Rails::Engine

    initializer "umlaut_borrow_direct.add_service_types" do |app|
      service_type_hash = Hash[UmlautBorrowDirect.service_type_values.collect {|v| [v, {}] }]
      ServiceTypeValue.merge_hash! service_type_hash
    end

  end
end
