module UmlautBorrowDirect
  # Used for whitelisting URLs.  You can specify a whitelist
  # in terms of a list of partial or complete URLs:
  #
  #     "//example.org"         # => Allows any URL at that host, any scheme
  #     "https://example.org"   # => "Just URLs beginning https://example.org"
  #     "//example.org/some/path" # => At that host AND with that specific path
  #
  #  Any combination of same.  The spec list defaults to Umlaut configuration
  #  at UmlautController.umlaut_config.borrow_direct.redirect_whitelist
  #
  # Then you can check:
  #     URLWhiteLister.new(array_of_specs).whitelisted?(url)
  #
  # url can be a string or URI instance. 
  #
  class UrlWhitelister
    attr_reader :whitelist_specs

    def initialize(whitelist_specs = UmlautController.umlaut_config.fetch("borrow_direct.redirect_whitelist", []))
      @whitelist_specs = whitelist_specs
    end

    def whitelisted?(url)
      return ! self.whitelist_specs.find do | spec |
        url_whitelisted_by_spec?(url, spec)
      end.nil?
    end

    # Does a given URL match a given whitelist spec?
    # whitelist spec like "//host.tld" or "https://host.tld"
    # or "//host.tld/path", etc. 
    def url_whitelisted_by_spec?(url, spec)
      begin
        parsed_url_parts  = URI.split(url)
      rescue URI::InvalidURIError
        return false
      end

      parsed_spec_parts = URI.split(spec)

      parsed_spec_parts.each_with_index do |part, index|
        if (! part.nil?) && (! part.empty?) && parsed_url_parts[index] != part
          return false
        end
      end

      # If we got this far without a return false, we're good. 
      return true
    end
  end
end