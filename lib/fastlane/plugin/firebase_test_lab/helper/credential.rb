require 'googleauth'

module Fastlane
  module FirebaseTestLab
    class Credential
      def initialize(key_file_path: nil)
        @key_file_path = key_file_path
      end

      def get_google_credential(scopes)
        return Google::Auth.get_application_default(scopes) unless @key_file_path

        File.open(@key_file_path, "r") do |file|
          return Google::Auth::ServiceAccountCredentials.read_json_key(file)
        end
      end
    end
  end
end
