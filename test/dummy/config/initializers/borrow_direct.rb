require 'borrow_direct'
BorrowDirect::Defaults.api_base = (defined?(VCRFilter)) ? VCRFilter[:bd_api_base] : ENV["BD_API_BASE"]
BorrowDirect::Defaults.api_key = (defined?(VCRFilter)) ? VCRFilter[:bd_api_key] : ENV["BD_API_KEY"]
BorrowDirect::Defaults.partnership_id = (defined?(VCRFilter)) ? VCRFilter[:bd_partnership_id] : ENV["BD_PARTNERSHIP_ID"]
