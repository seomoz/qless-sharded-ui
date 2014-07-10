# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "qless-sharded_ui"
  s.version     = 0.2
  s.authors     = ["Dan Lecocq"]
  s.email       = ["dan@seomoz.org"]
  s.homepage    = "http://github.com/seomoz/qless-sharded-ui"
  s.summary     = %q{A UI for Sharded Qless Installations}

  s.files         = %w(README.md Rakefile)
  s.files        += Dir.glob("lib/**/*.rb")
  s.files        += Dir.glob("bin/**/*")
  s.files        += Dir.glob("lib/qless/sharded_ui/**/*")
  s.bindir        = 'exe'
  s.executables   = [ "qless-sharded-web" ]

  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency 'redis'        , '>= 2.2' 
  
  s.add_dependency 'qless'        , '~> 0.9'
  s.add_development_dependency 'sinatra'      , '~> 1.3.2'
  s.add_development_dependency 'vegas'        , '~> 0.1'
  s.add_development_dependency 'rspec'        , '~> 2.12'
  s.add_development_dependency 'rspec-fire'   , '~> 1.1'
  s.add_development_dependency 'capybara'     , '~> 1.1.2'
  s.add_development_dependency 'poltergeist'  , '~> 1.0.0'
  s.add_development_dependency 'launchy'      , '~> 2.1.0'
  s.add_development_dependency 'pry'
end
