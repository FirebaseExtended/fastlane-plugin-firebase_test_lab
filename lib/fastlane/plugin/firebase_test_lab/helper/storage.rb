require 'googleauth'
require 'google/cloud/storage'

module Fastlane
  module FirebaseTestLab
    class Storage
      SCOPES = ["https://www.googleapis.com/auth/devstorage.full_control"]

      private_constant :SCOPES

      def initialize(gcp_project, credential)
        credentials = credential.get_google_credential(SCOPES)
        @client = Google::Cloud::Storage.new(project_id: gcp_project,
                                             credentials: credentials)
      end

      def self.upload_file(file_name, target_bucket, target_path)
        bucket = @client.bucket(target_bucket)
        bucket.create_file(file_name, target_path)
      end
    end
  end
end
