require 'googleauth'
require 'json'

require './error_helper'

module Fastlane
  module FirebaseTestLab
    class FirebaseTestLabService
      APIARY_ENDPOINT = "https://www.googleapis.com"
      TOOLRESULTS_GET_SETTINGS_API_V3 = "/toolresults/v1beta3/projects/{project}/settings"
      TOOLRESULTS_INITIALIZE_SETTINGS_API_V3 = "/toolresults/v1beta3/projects/{project}:initializeSettings"

      FIREBASE_TEST_LAB_ENDPOINT = "https://testing.googleapis.com"
      FTL_CREATE_API = "/v1/projects/{project}/testMatrices"
      FTL_RESULTS_API = "/v1/projects/{project}/testMatrices/{matrix}"

      TESTLAB_OAUTH_SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]

      private_constant :APIARY_ENDPOINT
      private_constant :TOOLRESULTS_GET_SETTINGS_API_V3
      private_constant :TOOLRESULTS_INITIALIZE_SETTINGS_API_V3
      private_constant :FIREBASE_TEST_LAB_ENDPOINT
      private_constant :FTL_CREATE_API
      private_constant :FTL_RESULTS_API
      private_constant :TESTLAB_OAUTH_SCOPES

      def initialize(credential)
        @auth = credential.get_google_credential(TESTLAB_OAUTH_SCOPES)
        @default_bucket = nil
      end

      def init_default_bucket(gcp_project)
        conn = Faraday.new(APIARY_ENDPOINT)
        begin
          conn.post(TOOLRESULTS_INITIALIZE_SETTINGS_API_V3.gsub("{project}", gcp_project)) do |req|
            req.headers = @auth.apply(req.headers)
            req.options.timeout = 15
            req.options.open_timeout = 5
          end
        rescue Faraday::Error => ex
          UI.abort_with_message!("Network error when initializing Firebase Test Lab, " \
            "type: #{ex.class}, message: #{ex.message}")
        end
      end

      def get_default_bucket(gcp_project)
        return @default_bucket unless @default_bucket.nil?

        init_default_bucket(gcp_project)
        conn = Faraday.new(APIARY_ENDPOINT)
        begin
          resp = conn.get(TOOLRESULTS_GET_SETTINGS_API_V3.gsub("{project}", gcp_project)) do |req|
            req.headers = @auth.apply(req.headers)
            req.options.timeout = 15
            req.options.open_timeout = 5
          end
        rescue Faraday::Error => ex
          UI.abort_with_message!("Network error when obtaining Firebase Test Lab default GCS bucket, " \
            "type: #{ex.class}, message: #{ex.message}")
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to obtain default bucket for Firebase Test Lab.")
          FastlaneCore::UI.abort_with_message!(ErrorHelper.summarize_google_error(resp.body))
          return nil
        else
          response_json = JSON.parse(resp.body)
          @default_bucket = response_json["defaultBucket"]
          return @default_bucket
        end
      end

      def start_job(gcp_project, app_path, result_path, devices, timeout_sec)
        body = {
          projectId: gcp_project,
          testSpecification: {
            testTimeout: {
              seconds: timeout_sec
            },
            iosTestSetup: {},
            iosXcTest: {
              testsZip: {
                gcsPath: app_path
              }
            }
          },
          environmentMatrix: {
            iosDeviceList: {
              iosDevices: devices.map(&FirebaseTestLabService.method(:map_device_to_proto))
            }
          },
          resultStorage: {
            googleCloudStorage: {
              gcsPath: result_path
            }
          }
        }

        conn = Faraday.new(FIREBASE_TEST_LAB_ENDPOINT)
        begin
          resp = conn.post(FTL_CREATE_API.gsub("{project}", gcp_project)) do |req|
            req.headers = @auth.apply(req.headers)
            req.headers["Content-Type"] = "application/json"
            req.headers["X-Goog-User-Project"] = gcp_project
            req.body = body.to_json
            req.options.timeout = 15
            req.options.open_timeout = 5
          end
        rescue Faraday::Error => ex
          UI.abort_with_message!("Network error when initializing Firebase Test Lab, " \
            "type: #{ex.class}, message: #{ex.message}")
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to start Firebase Test Lab jobs.")
          FastlaneCore::UI.error("Hint: Have you enrolled in Firebase Test Lab iOS beta tester program? It is " \
                                 "required during the beta testing. Click https://docs.google.com" \
                                 "/forms/d/e/1FAIpQLSf5cx1ot8ndHU9YrFkCn6gPoQZLxgW_6H13e_bot3he90n7Ng/viewform " \
                                 "to request access.")
          FastlaneCore::UI.abort_with_message!(ErrorHelper.summarize_google_error(resp.body))
        else
          response_json = JSON.parse(resp.body)
          return response_json["testMatrixId"]
        end
      end

      def get_matrix_results(gcp_project, matrix_id)
        url = FTL_RESULTS_API
                .gsub("{project}", gcp_project)
                .gsub("{matrix}", matrix_id)

        conn = Faraday.new(FIREBASE_TEST_LAB_ENDPOINT)
        begin
          resp = conn.get(url) do |req|
            req.headers = @auth.apply(req.headers)
            req.options.timeout = 15
            req.options.open_timeout = 5
          end
        rescue Faraday::Error => ex
          UI.abort_with_message!("Network error when attempting to get test results, " \
            "type: #{ex.class}, message: #{ex.message}")
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to obtain test results.")
          FastlaneCore::UI.abort_with_message!(ErrorHelper.summarize_google_error(resp.body))
          return nil
        else
          return JSON.parse(resp.body)
        end
      end

      def self.map_device_to_proto(device)
        {
          iosModelId: device[:ios_model_id],
          iosVersionId: device[:ios_version_id],
          locale: device[:locale],
          orientation: device[:orientation],
        }
      end
    end
  end
end
