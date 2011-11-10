# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pagerduty_tools/version"

Gem::Specification.new do |s|
  s.name        = "pagerduty_tools"
  s.version     = PagerdutyTools::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Marc Hedlund"]
  s.email       = ["marc@precipice.org"]  
  s.license     = "Apache 2.0"  
  s.homepage    = "https://github.com/precipice/pagerduty_tools"
  s.summary     = %q{Tools to work with PagerDuty.}
  s.description = %q{Set of libraries and command-line tools to make better use of PagerDuty.}

  s.rubyforge_project = "pagerduty_tools"
  s.required_ruby_version = '>= 1.8.7'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.0.17"
  s.add_development_dependency "fuubar",   "~> 0.0.5"
  
  s.add_runtime_dependency "chronic",   "~> 0.3.0"
  s.add_runtime_dependency "highline",  "~> 1.6.1"
  s.add_runtime_dependency "json",      "~> 1.5.1"
  s.add_runtime_dependency "mechanize", "~> 1.0.0"
  s.add_runtime_dependency "nokogiri",  "~> 1.4.7"
end
