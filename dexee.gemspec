$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "dexee/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "dexee"
  s.version     = Dexee::VERSION
  s.authors     = ["Jason Barnabe"]
  s.email       = ["jason.barnabe@gmail.com"]
  s.homepage    = "https://github.com/JasonBarnabe/dexee"
  s.summary     = "Rails CRUD engine"
  s.description = "Rails CRUD engine"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.1"
  s.add_dependency "simple_form", "~> 3.1.0"
  s.add_dependency "will_paginate"
  s.add_dependency "axlsx"
  s.add_dependency "acts_as_xlsx"
  s.add_dependency 'wicked_pdf'
  s.add_dependency 'public_activity'
  s.add_dependency 'responders', '~> 2.0'
  s.add_dependency 'strip_attributes'
  s.add_dependency 'schema_validations', "~> 1.2.0"
  s.add_dependency 'jquery-ui-rails'
  s.add_dependency 'simple-form-datepicker-reloaded'

end
