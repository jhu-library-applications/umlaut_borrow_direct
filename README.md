# UmlautBorrowDirect

IN PROGRESS

[![Build Status](https://travis-ci.org/jrochkind/umlaut_borrow_direct.svg)](https://travis-ci.org/jrochkind/umlaut_borrow_direct)

## Installation

You have an Umlaut app already (Umlaut 4.1+ required)

### Add umlaut_borrow_direct to your Gemfile:

~~~ruby
gem 'umlaut_borrow_direct'
~~~

### Configure the service in your `config/umlaut_services.yml`

~~~yaml
    borrow_direct:
      type: BorrowDirectAdaptor
      priority: d
      library_symbol: YOURSYMBOL
      find_item_patron_barcode: a_generic_barcode_that_can_be_used_for_FindItem_lookups
      html_query_base_url: https://example.edu/borrow_direct
~~~

If you want to take account of local availability (TBD), you want a priority
level after your local holdings lookup service. 

html_query_base_url is the URL for a local script that does auth and redirect to BD.
Your local script needs to pass on the `query` query param too. (Have different
integration needs? Let us know)

TODO: Pointing at production vs dev borrowdirect. Right now it's always dev. 

### Configure display of BorrowDirect responses

In your local `./app/controllers/umlaut_controller.rb`, in the
`umlaut_config.configure do` section, add:

~~~ruby
# Adds borrow_direct section to page
resolve_sections.insert_section UmlautBorrowDirect.resolve_section_definition, :before => "document_delivery"
# Supplies logic for when to highlight borrow_direct section
add_section_highlights_filter!  UmlautBorrowDirect.section_highlights_filter
~~~

### Add a local controller

Placing a request with BorrowDirect requires the current user's barcode. But Umlaut 
has no login system at all, and even if it did it wouldn't know how to figure out 
the current user's barcode in your local system. 

The solution at present is that you need to provide a BorrowDirectController
in your local app, that implements a #current_patron_barcode method that returns
the current user's barcode. It's also up to you to implement some kind of auth/login
system to enforce/determine the current user, which you can do in this controller,
or elsewhere. 

If you use Shibboleth, this might just be protecting the `/borrow_direct` URL in
your application with shibboleth, and then extracting the user's identity from
the Shibboleth-set environmental variables. In my own system, we need to do
another step to look up their barcode from their Shibboleth supplied identity. 

Your custom controller can raise a BorrowDirectController::UserReportableError
with a message to be shown to the user on any errors. 

Here's my own BorrowDirectController:

~~~ruby
# app/controllers/borrow_direct_controller.rb

require 'httpclient'
require 'nokogiri'
# Local override of BorrowDirectController from UmlautBorrowDirect, which
# uses Shibboleth to get a JHED lid to lookup a barcode. 
#
# Web app path /borrow_direct must be Shib protected in apache conf, or you'll
# get a "No authorized JHED information received error"
class BorrowDirectController < UmlautBorrowDirect::ControllerImplementation
  def patron_barcode
    # get from Shib
    jhed_lid = request.env['eppn']
    # strip off the @johnshopksins.edu
    jhed_lid.sub!(/\@johnshopkins\.edu$/, '')

    if jhed_lid.nil?
      raise UserReportableError.new("No authorized JHED information received, something has gone wrong.")
    end
    # Now we need to lookup the barcode though. 
    barcode = jhed_to_horizon_barcode(jhed_lid)
    if barcode.nil?
      raise UserReportableError.new("No Library Borrower account could be found for JHED login ID #{jhed_lid}. Please contact the Help Desk at your home library for help.")
    end

    return barcode
  end

  protected
  # use the borrower lookup HTTP service we already have running for Catalyst
  # lookup barcode. May need firewall opened on server service runs on. 
  def jhed_to_horizon_barcode(jhed_id)
    req_url = "#{UmlautJh::Application.config.horizon_borrower_lookup_url}?other_id=#{CGI.escape jhed_id}"
    http = HTTPClient.new
    xml = Nokogiri::XML(http.get_content(req_url))
    barcode = xml.at_xpath("borrowers/borrower/barcodes/barcode/text()").to_s
    if barcode.empty?
      barcode = nil
      Rails.logger.error("BorrowDirect: No barcode could be found for JHED `#{jhed_id}`. Requested `#{req_url}`. Response `#{xml.to_xml}`")
    end
    return barcode
  end
end
~~~



## Customizations

All text is done using Rails i18n, see `config/locales/en.yml` in this plugin's source. 
You can customize all text with a local locale file in your application, you need only
override keys you want to override. 

### Local Availability Check

By default, no Borrow Direct area will be shown on the screen if Umlaut believes
the item is locally available. 

By default, Umlaut knows the item is locally available if you have an
Umlaut service which produces :holding-type responses, and there
are holding responses present which:
* Have a :status included in configured `holdings.available_statuses` (by default 'Available')
* Do not have a `:match_reliability` set to `MatchUnsure`. 

You can customize the logic used for checking local availability, however
you like, including turning it off. Set a proc/lambda item in UmlautController
configuration borrow_direct.local_availability_check. The proc takes
two arguments, the Umlaut request, and the current BorrowDirectAdaptor service. 

For instance, to ignore local availability entirely:

~~~ruby
# app/controllers/umlaut_controller.rb
# ...
umlaut_config.configure do 
  borrow_direct do
    local_availability_check proc {|request, service|
      false
    }
  end
end
~~~

You can use the proc object in BorrowDirectAdaptor::DefaultLocalAvailabilityCheck
in your logic if you want. 

## Technical Details

### Custom ServiceTypeValue keys

bd_link_to_search: A link to search results in BD standard interface
* Standard service response with :display_text, :notes, and :url

bd_request_prompt:  a little form with a 'request' button, shows up
after confirmed requestability
* display_text
* pickup_locations => array of string pickup locations returned by BD

bd_not_available: indicates a 'not available' message should be shown (may not be used by default?)
* display_text

bd_request_status: A request is or has been placed
* status: BorrowDirectController::InProgress, BorrowDirectController::Successful, BorrowDirectController::Error
* request_number: BD request confirmation number, for succesful request
* error_user_message: An error message that can be shown publicly to user



