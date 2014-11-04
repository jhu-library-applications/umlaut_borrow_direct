# UmlautBorrowDirect

IN PROGRESS

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

    resolve_sections.insert_section UmlautBorrowDirect.resolve_section_definition, :before => "document_delivery"

## Customizations

All text is done using Rails i18n, see `config/locales/en.yml` in this plugin's source. 
You can customize all text with a local locale file in your application, you need only
override keys you want to override. 

## Technical Details