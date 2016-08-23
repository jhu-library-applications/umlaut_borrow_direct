# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

require 'vcr'
require 'webmock'
require 'minitest-vcr'

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Load fixtures from the engine
if ActiveSupport::TestCase.method_defined?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
end

require 'umlaut/test_help'
include Umlaut::TestHelp

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr_cassettes'
  c.hook_into :webmock # or :fakeweb

  # BD API requests tend to have their distinguishing
  # features in a POSTed JSON request body
  c.default_cassette_options = { :match_requests_on => [:method, :uri, :body] }
end

MinitestVcr::Spec.configure!

VCRFilter.sensitive_data! :bd_library_symbol
VCRFilter.sensitive_data! :bd_patron
VCRFilter.sensitive_data! :bd_api_key
VCRFilter.sensitive_data! :bd_api_base
