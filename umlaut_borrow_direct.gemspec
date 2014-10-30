$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "umlaut_borrow_direct/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "umlaut_borrow_direct"
  s.version     = UmlautBorrowDirect::VERSION
  s.authors     = ["Jonathan Rochkind"]
  s.email       = ["jonathan@dnil.net"]
  #s.homepage    = "TODO"
  s.summary     = "Umlaut plugin for BorrowDirect linking"  
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]
  
  s.add_dependency "umlaut", "~> 4.0"
  s.add_dependency "borrow_direct", "< 2"

  s.add_development_dependency "mysql2"

  s.add_development_dependency "minitest", "~> 5.0"
  s.add_development_dependency "minitest-spec-rails"
end
