require 'test_helper'

# test actual generated view with a live HTTP request. 


class BorrowDirectIntegrationTest < ActionDispatch::IntegrationTest
  # So-called "transactional fixtures" make all DB activity in a transaction,
  # which messes up Umlaut's background threading. 
  self.use_transactional_fixtures = false

    test "displays nothing for non-book-like items" do
      get "/resolve?genre=article&title=foo&author=bar"

      assert_no_service_errors

      assert_no_borrow_direct_section      
    end

    test "displays link without ISBN" do
      get "/resolve?genre=book&author=Smith&title=Some+Book"

      assert_no_service_errors

      assert_borrow_direct_section do      
        assert_select "a.response_link[href]", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.display_text")
        assert_select ".response_notes", :text => I18n.translate("umlaut.services.borrow_direct_adaptor.bd_link_to_search.notes")
      end
    end



  def assert_no_service_errors
    # the containers are there either way, have to check for content
    assert_select ".umlaut-section.service_errors h5", :count => 0
  end

  def assert_no_borrow_direct_section
    assert_select ".umlaut-section.borrow_direct", :count => 0
  end

  def assert_borrow_direct_section
    section = assert_select ".umlaut-section.borrow_direct", :count => 1 do
      assert_select ".section_heading h3", :text => I18n.t("umlaut.display_sections.borrow_direct.title")
      assert_select ".section_heading .section_prompt", :text => I18n.t("umlaut.display_sections.borrow_direct.prompt")

      yield if block_given?
    end

    return section
  end

end