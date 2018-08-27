require 'googleauth'

module Fastlane
  module FirebaseTestLab
    class Credential
      def initialize(key_file_path: nil)
        @key_file_path = key_file_path
      end

      def get_google_credential(scopes)
        unless @key_file_path
          begin
            return Google::Auth.get_application_default(scopes)
          rescue Error => ex
            UI.abort_with_message!("Failed reading application default credential. Either the Oauth credential should be provided or Google Application Default Credential should be configured: #{ex.message}")
          end
        end

        File.open(File.expand_path(@key_file_path), "r") do |file|
          options = {
            json_key_io: file,
            scope: scopes
          }
          begin
            return Google::Auth::ServiceAccountCredentials.make_creds(options)
          rescue Error => ex
            UI.abort_with_message!("Failed reading OAuth credential: #{ex.message}")
          end
        end
      end
    end
  end
end
