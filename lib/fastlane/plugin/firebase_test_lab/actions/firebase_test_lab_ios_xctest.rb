require_relative '../options'

module Fastlane
  module Actions
    class FirebaseTestLabIosXctestAction < Action
      def self.run(params)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Submit an iOS XCTest job to Firebase Test Lab"
      end

      def self.available_options
        Fastlane::FirebaseTestLab::Options.available_options
      end

      def self.authors
        ["@powerivq"]
      end

      def self.is_supported?(platform)
        return platform == :ios
      end
    end
  end
end
