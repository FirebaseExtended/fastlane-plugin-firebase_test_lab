require_relative '../helper/ftl_service'
require_relative '../helper/storage'
require_relative '../helper/credential'
require_relative '../options'

require 'json'
require 'securerandom'

module Fastlane
  module Actions
    class FirebaseTestLabIosXctestAction < Action
      FILE_NAME = "bundle"
      PULL_RESULT_INTERVAL = 5

      private_constant :FILE_NAME
      private_constant :PULL_RESULT_INTERVAL

      def self.run(params)
        gcp_project = params[:gcp_project]
        oauth_key_file = params[:oauth_key_file]
        gcp_credential = Fastlane::FirebaseTestLab::Credential.new(key_file_path: oauth_key_file)

        ftl_service = Fastlane::FirebaseTestLab::FirebaseTestLabService.new(gcp_credential)
        artifact_directory = generate_directory_name + "/"

        if params[:app_path].to_s.start_with?("gs://")
          gcs_file_name = params[:app_path]
        else
          upload_bucket_name = ftl_service.get_default_bucket(gcp_project)
          gcs_file_name = upload_file(params[:app_path], upload_bucket_name, artifact_directory, gcp_project, gcp_credential)
        end

        UI.message("Submitting job(s) to Firebase Test Lab")
        result_bucket_name = ftl_service.get_default_bucket(gcp_project)
        result_storage = (params[:result_storage] or "gs://#{result_bucket_name}/#{artifact_directory}")
        matrix_id = ftl_service.start_job(gcp_project, gcs_file_name, result_storage, params[:devices],
                                          params[:timeout_sec])
        if matrix_id.nil?
          UI.error!("No matrix ID received.")
        end
        UI.message("Matrix ID for this submission: #{matrix_id}")
        if params[:async]
          UI.success("Jobs are submitted to Firebase Test Lab")
        end

        UI.message("Waiting for test results...")
        return wait_for_test_results(ftl_service, gcp_project, matrix_id)
      end

      def self.upload_file(app_path, bucket_name, artifact_directory, gcp_project, gcp_credential)
        file_name = "gs://#{bucket_name}/#{artifact_directory}" + FILE_NAME
        UI.message("Uploading " + app_path + " to #{file_name}")
        storage = Fastlane::FirebaseTestLab::Storage.new(gcp_project, gcp_credential)
        storage.upload_file(app_path, bucket_name, artifact_directory + FILE_NAME)
        UI.message("Upload completed")
        return file_name
      end

      def self.wait_for_test_results(ftl_service, gcp_project, matrix_id)
        while true
          results = ftl_service.get_matrix_results(gcp_project, matrix_id)
          case results["state"]
          when "FINISHED"
            UI.message("Test jobs are completed")
            UI.message("-------------------------")
            UI.message("|        RESULTS        |")
            UI.message("-------------------------")
            failures = 0
            for execution in results["testExecutions"]
              UI.message(execution["id"] + ": " + execution["state"])
              if execution["state"] != "FINISHED"
                failures += 1
              end
            end
            if failures > 0
              UI.test_failure!("Some tests on Firebase Test Lab have failed")
              return false
            else
              UI.success("All jobs finished successfully")
              return true
            end
          when "ERROR"
            UI.user_error!("The execution or matrix has stopped because it encountered an infrastructure failure.")
            return false
          when "UNSUPPORTED_ENVIRONMENT"
            UI.user_error!("The execution was not run because it corresponds to a unsupported environment.")
            return false
          when "INCOMPATIBLE_ENVIRONMENT"
            UI.user_error!("The execution was not run because the provided inputs are incompatible with the " \
                           "requested environment")
            return false
          when "INCOMPATIBLE_ARCHITECTURE"
            UI.user_error!("The execution was not run because the provided inputs are incompatible with the " \
                           "requested architecture.")
            return false
          when "CANCELLED"
            UI.user_error!("The user cancelled the execution.")
            return false
          when "INVALID"
            UI.error!("The execution or matrix was not run because the provided inputs are not valid.")
            return false
          end
          sleep(PULL_RESULT_INTERVAL)
        end
      end

      def self.generate_directory_name
        SecureRandom.hex
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Submit an iOS XCTest job to Firebase Test Lab"
      end

      def self.available_options
        Fastlane::FirebaseTestLab::Options.available_options
      end

      def self.authors
        ["powerivq"]
      end

      def self.is_supported?(platform)
        return platform == :ios
      end
    end
  end
end
