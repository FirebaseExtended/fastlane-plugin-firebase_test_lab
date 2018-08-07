require 'googleauth'
require 'json'

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
      private_constant :GCS_OAUTH_SCOPES

      def initialize(credential)
        @auth = credential.get_google_credential(TESTLAB_OAUTH_SCOPES)
      end

      def self.init_default_bucket(gcp_project)
        conn = Faraday.new(APIARY_ENDPOINT)
        conn.post(TOOLRESULTS_INITIALIZE_SETTINGS_API_V3.gsub("{project}", gcp_project)) do |req|
          req.headers = @auth.apply(req.headers)
        end
      end

      def self.get_default_bucket(gcp_project)
        conn = Faraday.new(APIARY_ENDPOINT)
        resp = conn.get(TOOLRESULTS_GET_SETTINGS_API_V3.gsub("{project}", gcp_project)) do |req|
          req.headers = @auth.apply(req.headers)
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to obtain default bucket for Firebase Test Lab.")
          FastlaneCore::UI.error(resp.body)
          return nil
        else
          response_json = JSON.parse(resp.body)
          return response_json["defaultBucket"]
        end
      end

      def self.start_job(gcp_project, app_path, result_path, devices, timeout_sec)
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
              iosDevices: devices
            }
          },
          resultStorage: {
            googleCloudStorage: {
              gcsPath: result_path
            }
          }
        }

        conn = Faraday.new(FIREBASE_TEST_LAB_ENDPOINT)
        resp = conn.post(FTL_CREATE_API.gsub("{project}", gcp_project)) do |req|
          req.headers = @auth.apply(req.headers)
          req.headers["Content-Type"] = "application/json"
          req.headers["X-Goog-User-Project"] = gcp_project
          req.body = body.to_json
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to start Firebase Test Lab jobs.")
          FastlaneCore::UI.error(resp.body)
          return nil
        else
          response_json = JSON.parse(resp.body)
          return response_json["testMatrixId"]
        end
      end

      def self.get_matrix_results(gcp_project, matrix_id)
        url = FTL_RESULTS_API
                .gsub("{project}", gcp_project)
                .gsub("{matrix}", matrix_id)

        conn = Faraday.new(FIREBASE_TEST_LAB_ENDPOINT)
        resp = conn.get(url) do |req|
          req.headers = @auth.apply(req.headers)
        end

        if resp.status != 200
          FastlaneCore::UI.error("Failed to obtain test results.")
          FastlaneCore::UI.error(resp.body)
          return nil
        else
          return JSON.parse(resp.body)
        end
      end
    end
  end
end
