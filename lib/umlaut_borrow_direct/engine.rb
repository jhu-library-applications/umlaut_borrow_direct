module UmlautBorrowDirect
  class Engine < ::Rails::Engine

    initializer "umlaut_borrow_direct.add_service_types" do |app|
      our_yml_file = File.expand_path("config/service_type_values.yml", self.root)
      ServiceTypeValue.merge_yml_file! our_yml_file
    end

  end
end
