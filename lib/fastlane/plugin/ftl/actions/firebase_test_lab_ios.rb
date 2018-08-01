module Fastlane
  module Actions
    class FirebaseTestLabIosAction < Action
      def self.run(params)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Submit an iOS test job to Firebase Test Lab"
      end

      def self.available_options
        []
      end

      def self.authors
        ["@powerivq"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
