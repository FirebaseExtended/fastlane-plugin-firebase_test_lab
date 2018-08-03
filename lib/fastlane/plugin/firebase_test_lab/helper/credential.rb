require 'googleauth'

module Fastlane
  module FirebaseTestLab
    class Credential
      def initialize(key_file)
        @key_file = key_file
      end

      def self.get_google_credential(scopes)
        if @key_file
          File.open(@key_file, "r") do |f|
            return Google::Auth::ServiceAccountCredentials.read_json_key(f)
          end
        else
          return Google::Auth.get_application_default(scopes)
        end
      end
    end
  end
end
