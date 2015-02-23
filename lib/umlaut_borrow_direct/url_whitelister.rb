module UmlautBorrowDirect
  # Used for whitelisting URLs.  You can specify a whitelist
  # in terms of a list of partial or complete URLs:
  #
  #     "//example.org"         # => Allows any URL at that host, any scheme
  #     "https://example.org"   # => "Just URLs beginning https://example.org"
  #     "//example.org/some/path" # => At that host AND with that specific path
  #
  # To wildcard hosts, use a trailing period. 
  #
  #      "//.example.org" # => Matches any *.example.org or "example.org"
  #
  # Whitelist is an array of zero or more such specs. 
  #
  # Then you can check:
  #     URLWhiteLister.new(array_of_specs).whitelisted?(url)
  #
  # url can be a string or URI instance. 
  #
  class UrlWhitelister
    attr_reader :whitelist_specs

    # Initialize with an array of one or more valid specs. 
    def initialize(whitelist_specs)
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
    #
    # You can do a wildcard host with a prefix period, for instance
    # "//.example.org" will match "foo.example.org" as well as "example.org"
    def url_whitelisted_by_spec?(url, spec)
      parsed_url = url
      begin
        parsed_url  = URI.parse(url) unless parsed_url.kind_of?(URI)
      rescue URI::InvalidURIError
        return false
      end

      parsed_spec = spec.kind_of?(URI) ? spec : URI.parse(spec)

      # Don't include 'host' yet, we check that special for wildcards. 
      part_list = [:scheme, :userinfo, :port, :path, :query, :fragment]

      # special handling for hosts to support trailing period as wildcard
      spec_host = parsed_spec.host

      if spec_host && spec_host.start_with?(".")
        return false unless (parsed_url.host.ends_with?(spec_host) || parsed_url.host == spec_host.slice(1..-1))
      elsif spec_host && (! spec_host.empty?)
        # just check it normally below
        part_list << :host
      end


      # Other parts, just match if spec part is not empty
      part_list.each do |part|
        spec_part = parsed_spec.send(part).to_s
        if (! spec_part.nil?) && (! spec_part.empty?) && 
              (parsed_url.send(part).to_s != spec_part )
          return false
        end
      end

      # If we got this far without a return false, we're good. 
      return true
    end
  end
end