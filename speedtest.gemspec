# encoding: utf-8

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'speedtest/version'

Gem::Specification.new do |spec|
  spec.name          = "plr-speedtest"
  spec.version       = Speedtest::VERSION
  spec.authors       = ["Pete Myron", "Philippe Le Rohellec"]
  spec.email         = ["pete.myron@gmail.com", "philippe.lerohellec@gmail.com"]

  spec.summary       = %q{Gemmed version of lacostej's speedtest.rb script - Test your speed with speedtest.net!}
  spec.description   = %q{Gemmed version of lacostej's speedtest.rb script @ https://github.com/lacostej/speedtest.rb - Test your speed with speedtest.net!}
  spec.homepage      = "https://github.com/petemyron/speedtest"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "httparty", "~> 0.13"
  spec.add_runtime_dependency "celluloid", "~> 0.17.3"
  spec.add_runtime_dependency "curb"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "amazing_print"
  spec.add_development_dependency "byebug"
end
