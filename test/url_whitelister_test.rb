require 'test_helper'

require 'umlaut_borrow_direct/url_whitelister'

describe "UmlautBorrowDirect::UrlWhitelister" do
  it "rejects on a null whitelist" do
    refute UmlautBorrowDirect::UrlWhitelister.new([]).whitelisted?("http://example.org")
  end

  it "rejects a non-URI" do
    refute UmlautBorrowDirect::UrlWhitelister.new([]).whitelisted?("foo bar baz")
    refute UmlautBorrowDirect::UrlWhitelister.new(["//example.org"]).whitelisted?("foo bar baz")
  end

  it "accepts a bunch of things" do
    assert UmlautBorrowDirect::UrlWhitelister.new(["https://example.org"]).whitelisted?("https://example.org")
    assert UmlautBorrowDirect::UrlWhitelister.new(["//example.org"]).whitelisted?("http://example.org")
    assert UmlautBorrowDirect::UrlWhitelister.new(["//example.org", "//otherexample.org"]).whitelisted?("http://example.org")
    assert UmlautBorrowDirect::UrlWhitelister.new(["//example.org"]).whitelisted?("http://example.org/")
    assert UmlautBorrowDirect::UrlWhitelister.new(["//example.org"]).whitelisted?("http://example.org/some/path")
    assert UmlautBorrowDirect::UrlWhitelister.new(["https://example.org"]).whitelisted?("https://example.org/")
    assert UmlautBorrowDirect::UrlWhitelister.new(["//example.org/some/path"]).whitelisted?("https://example.org/some/path")
  end

  it "rejects a bunch of things" do
    refute UmlautBorrowDirect::UrlWhitelister.new(["//example.org"]).whitelisted?("http://bad-example.org")
    refute UmlautBorrowDirect::UrlWhitelister.new(["//example.org", "//other-example.org"]).whitelisted?("http://bad-example.org")
    refute UmlautBorrowDirect::UrlWhitelister.new(["https://example.org"]).whitelisted?("http://example.org")
    refute UmlautBorrowDirect::UrlWhitelister.new(["https://example.org/some/path"]).whitelisted?("http://example.org")
    refute UmlautBorrowDirect::UrlWhitelister.new(["https://example.org/some/path"]).whitelisted?("http://example.org/other/path")
    refute UmlautBorrowDirect::UrlWhitelister.new(["https://example.org/some/path"]).whitelisted?("http://example.org/other/path/more")
  end

  it "allows wildcarded hostname with leading dot" do
    assert UmlautBorrowDirect::UrlWhitelister.new(["//.example.org"]).whitelisted?("http://foo.example.org")
#    assert UmlautBorrowDirect::UrlWhitelister.new(["//.example.org"]).whitelisted?("http://example.org")
#    refute UmlautBorrowDirect::UrlWhitelister.new(["//.example.org"]).whitelisted?("http://foo.11example.org")

  end


end