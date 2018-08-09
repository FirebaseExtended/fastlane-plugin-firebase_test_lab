require_relative '../helper/ftl_service'
require_relative '../helper/storage'
require_relative '../helper/credential'
require_relative '../options'

require 'json'
require 'securerandom'
require 'tty-spinner'

module Fastlane
  module Actions
    class FirebaseTestLabIosXctestAction < Action
      DEFAULT_APP_BUNDLE_NAME = "bundle"
      PULL_RESULT_INTERVAL = 5

      ERROR_CODE_TO_MESSAGE = {
        ERROR: "The execution or matrix has stopped because it encountered an infrastructure failure.",
        UNSUPPORTED_ENVIRONMENT: "The execution was not run because it corresponds to a unsupported environment.",
        INCOMPATIBLE_ENVIRONMENT: "The execution was not run because the provided inputs are incompatible with the " \
                                  "requested environment",
        INCOMPATIBLE_ARCHITECTURE: "The execution was not run because the provided inputs are incompatible with the " \
                                   "requested architecture.",
        CANCELLED: "The user cancelled the execution.",
        INVALID: "The execution or matrix was not run because the provided inputs are not valid.",
      }

      private_constant :DEFAULT_APP_BUNDLE_NAME
      private_constant :PULL_RESULT_INTERVAL
      private_constant :ERROR_CODE_TO_MESSAGE

      def self.run(params)
        gcp_project = params[:gcp_project]
        oauth_key_file = params[:oauth_key_file]
        gcp_credential = Fastlane::FirebaseTestLab::Credential.new(key_file_path: oauth_key_file)

        ftl_service = Fastlane::FirebaseTestLab::FirebaseTestLabService.new(gcp_credential)
        gcs_workfolder = generate_directory_name

        if params[:app_path].to_s.start_with?("gs://")
          app_gcs_link = params[:app_path]
        else
          upload_spinner = TTY::Spinner.new("[:spinner] Uploading the app to GCS...", format: :dots)
          upload_spinner.auto_spin
          upload_bucket_name = ftl_service.get_default_bucket(gcp_project)
          app_gcs_link = upload_file(params[:app_path],
                                     upload_bucket_name,
                                     "#{gcs_workfolder}/#{DEFAULT_APP_BUNDLE_NAME}",
                                     gcp_project,
                                     gcp_credential)
          upload_spinner.success("Done")
        end

        UI.message("Submitting job(s) to Firebase Test Lab")
        result_storage = (params[:result_storage] or
          "gs://#{ftl_service.get_default_bucket(gcp_project)}/#{gcs_workfolder}")
        matrix_id = ftl_service.start_job(gcp_project,
                                          app_gcs_link,
                                          result_storage,
                                          params[:devices],
                                          params[:timeout_sec])
        if matrix_id.nil?
          UI.abort_with_message!("No matrix ID received.")
        end
        UI.message("Matrix ID for this submission: #{matrix_id}")
        if params[:async]
          UI.success("Jobs have been submitted to Firebase Test Lab")
        end

        return wait_for_test_results(ftl_service, gcp_project, matrix_id)
      end

      def self.upload_file(app_path, bucket_name, gcs_path, gcp_project, gcp_credential)
        file_name = "gs://#{bucket_name}/#{gcs_path}"
        storage = Fastlane::FirebaseTestLab::Storage.new(gcp_project, gcp_credential)
        storage.upload_file(app_path, bucket_name, gcs_path)
        return file_name
      end

      def self.wait_for_test_results(ftl_service, gcp_project, matrix_id)
        has_shown_console_link = false

        spinner = TTY::Spinner.new("[:spinner] Starting tests...", format: :dots)
        spinner.auto_spin

        while true
          results = ftl_service.get_matrix_results(gcp_project, matrix_id)
          if !has_shown_console_link && !results["resultStorage"].nil? &&
              !results["resultStorage"]["toolResultsExecution"].nil?
            has_shown_console_link = true
            tool_results_execution = results["resultStorage"]["toolResultsExecution"]
            history_id = tool_results_execution["historyId"]
            execution_id = tool_results_execution["executionId"]
            spinner.success("Done")
            UI.message("Click https://console.firebase.google.com" \
              "/project/#{gcp_project}/testlab/histories/#{history_id}/matrices/#{execution_id} for more information " \
              "about this run")
            spinner = TTY::Spinner.new("[:spinner] Waiting for results...", format: :dots)
            spinner.auto_spin
          end

          state = results["state"]
          if ERROR_CODE_TO_MESSAGE.key?(state)
            spinner.error("Failed")
            UI.user_error!(ERROR_CODE_TO_MESSAGE[state])
            return false
          end

          if state == "FINISHED"
            spinner.success("Done")
            UI.message("Test jobs are completed")
            UI.message("-------------------------")
            UI.message("|        RESULTS        |")
            UI.message("-------------------------")
            failures = 0
            for execution in results["testExecutions"]
              execution_info = "#{execution['id']} is #{execution['state']}"
              if execution["state"] != "FINISHED"
                failures += 1
                UI.error(execution_info)
              else
                UI.success(execution_info)
              end
            end
            if failures > 0
              UI.test_failure!("Some tests on Firebase Test Lab have failed")
              return false
            else
              UI.success("🎉All jobs finished successfully")
              return true
            end
          end

          sleep(PULL_RESULT_INTERVAL)
        end
      end

      def self.generate_directory_name
        timestamp = Time.now.getutc.strftime "%Y%m%d-%H%M%SZ"
        return "fastlane-#{timestamp}-#{SecureRandom.hex[0..5]}"
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
