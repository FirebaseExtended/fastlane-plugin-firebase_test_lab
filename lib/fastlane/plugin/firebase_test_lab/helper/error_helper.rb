require 'json'

module Fastlane
  module FirebaseTestLab
    class ErrorHelper
      def self.summarize_google_error(payload)
        begin
          response = JSON.parse(payload)
        rescue JSON::ParserError => ex
          return payload
        end

        if response["error"]
          return response["error"]["message"]
        end
        return payload
      end
    end
  end
end
