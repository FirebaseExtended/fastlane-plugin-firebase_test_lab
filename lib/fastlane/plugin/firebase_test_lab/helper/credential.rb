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
          options = {
            json_key_io: file,
            scope: scopes
          }
          return Google::Auth::ServiceAccountCredentials.make_creds(options)
        end
      end
    end
  end
end
