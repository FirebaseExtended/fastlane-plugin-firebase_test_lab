require_relative '../helper/ftl_service'
require_relative '../helper/storage'
require_relative '../helper/credential'
require_relative '../helper/ios_validator'
require_relative '../options'

require 'json'
require 'securerandom'
require 'tty-spinner'

module Fastlane
  module Actions
    class FirebaseTestLabIosXctestAction < Action
      DEFAULT_APP_BUNDLE_NAME = "bundle"
      PULL_RESULT_INTERVAL = 5

      RUNNING_STATES = %w(VALIDATING PENDING RUNNING)
      ERROR_STATE_TO_MESSAGE = {
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
      private_constant :RUNNING_STATES
      private_constant :ERROR_STATE_TO_MESSAGE

      def self.run(params)
        gcp_project = params[:gcp_project]
        oauth_key_file_path = params[:oauth_key_file_path]
        gcp_credential = Fastlane::FirebaseTestLab::Credential.new(key_file_path: oauth_key_file_path)

        ftl_service = Fastlane::FirebaseTestLab::FirebaseTestLabService.new(gcp_credential)

        # The default Google Cloud Storage path we store app bundle and test results
        gcs_workfolder = generate_directory_name

        if params[:app_path].nil?
          UI.user_error!("app_path argument is not provided, and no build artifact through the scan action is " \
                         "detected, so we do not know where your app is! Please either provide the path to the " \
                         "app or add the scan action before this Firebase Test Lab action. See " \
                         "https://github.com/fastlane/fastlane-plugin-firebase_test_lab for details.")
        end

        # Firebase Test Lab requires an app bundle be already on Google Cloud Storage before starting the job
        if params[:app_path].to_s.start_with?("gs://")
          # gs:// is a path on Google Cloud Storage, we do not need to re-upload the app to a different bucket
          app_gcs_link = params[:app_path]
        else
          FirebaseTestLab::IosValidator.validate_ios_app(params[:app_path])

          # When given a local path, we upload the app bundle to Google Cloud Storage
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

        # We have gathered all the information. Call Firebase Test Lab to start the job now
        matrix_id = ftl_service.start_job(gcp_project,
                                          app_gcs_link,
                                          result_storage,
                                          params[:devices],
                                          params[:timeout_sec])

        # In theory, matrix_id should be available. Keep it to catch unexpected Firebase Test Lab API response
        if matrix_id.nil?
          UI.abort_with_message!("No matrix ID received.")
        end
        UI.message("Matrix ID for this submission: #{matrix_id}")
        wait_for_test_results(ftl_service, gcp_project, matrix_id, params[:async])
      end

      def self.upload_file(app_path, bucket_name, gcs_path, gcp_project, gcp_credential)
        file_name = "gs://#{bucket_name}/#{gcs_path}"
        storage = Fastlane::FirebaseTestLab::Storage.new(gcp_project, gcp_credential)
        storage.upload_file(File.expand_path(app_path), bucket_name, gcs_path)
        return file_name
      end

      def self.wait_for_test_results(ftl_service, gcp_project, matrix_id, async)
        firebase_console_link = nil

        spinner = TTY::Spinner.new("[:spinner] Starting tests...", format: :dots)
        spinner.auto_spin

        # Keep pulling test results until they are ready
        while true
          results = ftl_service.get_matrix_results(gcp_project, matrix_id)

          if firebase_console_link.nil?
            history_id, execution_id = try_get_history_id_and_execution_id(results)
            # Once we get the Firebase console link, we display that exactly once
            unless history_id.nil? || execution_id.nil?
              firebase_console_link = "https://console.firebase.google.com" \
                "/project/#{gcp_project}/testlab/histories/#{history_id}/matrices/#{execution_id}"

              spinner.success("Done")
              UI.message("Go to #{firebase_console_link} for more information about this run")

              if async
                UI.success("Job(s) have been submitted to Firebase Test Lab")
                return
              end

              spinner = TTY::Spinner.new("[:spinner] Waiting for results...", format: :dots)
              spinner.auto_spin
            end
          end

          state = results["state"]
          # Handle all known error statuses
          if ERROR_STATE_TO_MESSAGE.key?(state.to_sym)
            spinner.error("Failed")
            UI.user_error!(ERROR_STATE_TO_MESSAGE[state.to_sym])
          end

          if state == "FINISHED"
            spinner.success("Done")
            # Inspect the execution results: only contain info on whether each job finishes.
            # Do not include whether tests fail
            executions_completed = extract_execution_results(results)

            if results["resultStorage"].nil? || results["resultStorage"]["toolResultsExecution"].nil?
              UI.abort_with_message!("Unexpected response from Firebase test lab: Cannot retrieve result info")
            end

            # Now, look at the actual test result and see if they succeed
            history_id, execution_id = try_get_history_id_and_execution_id(results)
            if history_id.nil? || execution_id.nil?
              UI.abort_with_message!("Unexpected response from Firebase test lab: No history or execution ID")
            end
            test_results = ftl_service.get_execution_steps(gcp_project, history_id, execution_id)
            tests_successful = extract_test_results(test_results, gcp_project, history_id, execution_id)
            unless executions_completed && tests_successful
              UI.test_failure!("Tests failed")
            end
            return
          end

          # We should have caught all known states here. If the state is not one of them, this
          # plugin should be modified to handle that
          unless RUNNING_STATES.include?(state)
            spinner.error("Failed")
            UI.abort_with_message!("The test execution is in an unknown state: #{state}. " \
              "We appreciate if you could notify us at " \
              "https://github.com/fastlane/fastlane-plugin-firebase_test_lab/issues")
          end
          sleep(PULL_RESULT_INTERVAL)
        end
      end

      def self.generate_directory_name
        timestamp = Time.now.getutc.strftime "%Y%m%d-%H%M%SZ"
        return "fastlane-#{timestamp}-#{SecureRandom.hex[0..5]}"
      end

      def self.try_get_history_id_and_execution_id(matrix_results)
        if matrix_results["resultStorage"].nil? || matrix_results["resultStorage"]["toolResultsExecution"].nil?
          return nil, nil
        end

        tool_results_execution = matrix_results["resultStorage"]["toolResultsExecution"]
        history_id = tool_results_execution["historyId"]
        execution_id = tool_results_execution["executionId"]
        return history_id, execution_id
      end

      def self.extract_execution_results(execution_results)
        UI.message("Test job(s) are finalized")
        UI.message("-------------------------")
        UI.message("|   EXECUTION RESULTS   |")
        failures = 0
        execution_results["testExecutions"].each do |execution|
          UI.message("-------------------------")
          execution_info = "#{execution['id']}: #{execution['state']}"
          if execution["state"] != "FINISHED"
            failures += 1
            UI.error(execution_info)
          else
            UI.success(execution_info)
          end

          # Display build logs
          if !execution["testDetails"].nil? && !execution["testDetails"]["progressMessages"].nil?
            execution["testDetails"]["progressMessages"].each {|msg| UI.message(msg)}
          end
        end

        UI.message("-------------------------")
        if failures > 0
          UI.error("😞  #{failures} execution(s) have failed to complete.")
        else
          UI.success("🎉  All jobs have ran and completed.")
        end
        return failures == 0
      end

      def self.extract_test_results(test_results, gcp_project, history_id, execution_id)
        steps = test_results["steps"]
        failures = 0
        inconclusive_runs = 0

        UI.message("-------------------------")
        UI.message("|      TEST OUTCOME     |")
        steps.each do |step|
          UI.message("-------------------------")
          step_id = step["stepId"]
          UI.message("Test step: #{step_id}")

          run_duration_sec = step["runDuration"]["seconds"] || 0
          UI.message("Execution time: #{run_duration_sec} seconds")

          outcome = step["outcome"]["summary"]
          case outcome
          when "success"
            UI.success("Result: #{outcome}")
          when "skipped"
            UI.message("Result: #{outcome}")
          when "inconclusive"
            inconclusive_runs += 1
            UI.error("Result: #{outcome}")
          when "failure"
            failures += 1
            UI.error("Result: #{outcome}")
          end
          UI.message("For details, go to https://console.firebase.google.com/project/#{gcp_project}/testlab/" \
            "histories/#{history_id}/matrices/#{execution_id}/executions/#{step_id}")
        end

        UI.message("-------------------------")
        if failures == 0 && inconclusive_runs == 0
          UI.success("🎉  Yay! All executions are completed successfully!")
        end
        if failures > 0
          UI.error("😞  #{failures} step(s) have failed.")
        end
        if inconclusive_runs > 0
          UI.error("😞  #{inconclusive_runs} step(s) yielded inconclusive outcomes.")
        end
        return failures == 0 && inconclusive_runs == 0
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
