# Local implementation of BorrowDirectController in dummy app,
# with local #patron_barcode method, that in our test dummy app
# takes from ENV/VCRFilter
class BorrowDirectController < UmlautBorrowDirect::ControllerImplementation
  # used for testing to test with bad barcodes
  @@force_patron_barcode = nil
  def self.force_patron_barcode=(v)
    @@force_patron_barcode = v
  end

  def patron_barcode
    return @@force_patron_barcode if @@force_patron_barcode

    if defined? VCRFilter
      VCRFilter[:bd_patron]
    else
      ENV["BD_PATRON"]
    end
  end
end