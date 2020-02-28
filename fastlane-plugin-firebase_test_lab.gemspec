
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/firebase_test_lab/module'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-firebase_test_lab'
  spec.version       = Fastlane::FirebaseTestLab::VERSION
  spec.author        = 'Shihua Zheng'
  spec.email         = 'shihuaz@google.com'

  spec.summary       = 'Test your app with Firebase Test Lab with ease using fastlane'
  spec.homepage      = "https://github.com/fastlane/fastlane-plugin-firebase_test_lab"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency('faraday')
  spec.add_dependency('googleauth')
  spec.add_dependency('rubyzip', '>= 1.0.0')
  spec.add_dependency('plist', '>= 3.0.0')
  spec.add_dependency('google-cloud-storage', '~> 1.25.1')
  spec.add_dependency('tty-spinner', '>= 0.8.0', '< 1.0.0')

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '>= 2.102.0')
  spec.add_development_dependency('rubocop', '<= 0.50.0')
end
