require 'googleauth'

module Fastlane
  module FirebaseTestLab
    class Credential
      def initialize(key_file_path)
        @key_file_path = key_file_path
      end

      def self.get_google_credential(scopes)
        if @key_file_path
          File.open(@key_file_path, "r") do |file|
            return Google::Auth::ServiceAccountCredentials.read_json_key(file)
          end
        else
          return Google::Auth.get_application_default(scopes)
        end
      end
    end
  end
end
