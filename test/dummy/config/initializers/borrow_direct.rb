require 'borrow_direct'
BorrowDirect::Defaults.api_base = (ENV["BD_API_BASE"]) ? ENV["BD_API_BASE"] : 'https://bdtest.relais-host.com'
BorrowDirect::Defaults.api_key = (ENV["BD_API_KEY"]) ? ENV["BD_API_KEY"] : 'DUMMY_BD_API_KEY'
BorrowDirect::Defaults.partnership_id = (ENV["BD_PARTNERSHIP_ID"]) ? ENV["BD_PARTNERSHIP_ID"] : 'DUMMY_BD_PARTNERSHIP_ID'
