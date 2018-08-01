# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/ftl/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-ftl'
  spec.version       = Fastlane::Ftl::VERSION
  spec.author        = %q{Shihua Zheng}
  spec.email         = %q{shihuaz@google.com}

  spec.summary       = %q{Firebase Test Lab for fastlane}
  spec.homepage      = "https://github.com/fastlane/fastlane-ftl-plugin"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # spec.add_dependency 'your-dependency', '~> 1.0.0'
  spec.add_dependency 'faraday'
  spec.add_dependency 'googleauth'
  spec.add_dependency 'google-cloud-storage', '~> 1.13.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'fastlane', '>= 1.90.0'
end
