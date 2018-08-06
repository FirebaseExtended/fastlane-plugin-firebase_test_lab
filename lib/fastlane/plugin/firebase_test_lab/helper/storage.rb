require 'googleauth'
require 'google/cloud/storage'

module Fastlane
  module FirebaseTestLab
    class Storage
      GCS_OAUTH_SCOPES = ["https://www.googleapis.com/auth/devstorage.full_control"]

      private_constant :GCS_OAUTH_SCOPES

      def initialize(gcp_project, credential)
        credentials = credential.get_google_credential(GCS_OAUTH_SCOPES)
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
