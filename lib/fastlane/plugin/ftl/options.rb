require 'fastlane_core/configuration/config_item'

module Fastlane
  module Ftl
    class Optinos
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :gcp_project,
                                       description: "Google Cloud Platform project name",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       description: "Path to the app, either on the filesystem or GCS address (gs://)",
                                       optional: false,
                                       verify_block: proc do |value|
                                         unless value.to_s.start_with?("gs://")
                                           v = File.expand_path(value.to_s)
                                           UI.user_error!("App file not found at path '#{v}'") unless File.exist?(v)
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :devices,
                                       description: "Devices to test the app on",
                                       optional: false,
                                       type: Array,
                                       verify_block: proc do |value|
                                         value.each do |current|
                                           UI.user_error!("Each device must be represented by a Hash object, #{current.class} found") if current.class != Hash
                                           check_has_property(current, :iosModelId)
                                           check_has_property(current, :iosVersionId)
                                           check_has_property(current, :locale)
                                           check_has_property(current, :orientation)
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :async,
                                       description: "Do not wait for test results",
                                       default_value: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("async must be either true or false") if value != true && value != false
                                       end),
          FastlaneCore::ConfigItem.new(key: :timeout_sec,
                                       description: "After how long, in seconds, should tests be terminated",
                                       default_value: 900,
                                       verify_block: proc do |value|
                                         UI.user_error!("Timeout must be a positive number") if value <= 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :result_storage,
                                       description: "GCS path to store test results",
                                       default_value: nil,
                                       verify_block: proc do |value|
                                         UI.user_error!("Invalid GCS path: '#{value}'") unless value.match(/^gs:\/\/.*\//)
                                       end),
          FastlaneCore::ConfigItem.new(key: :oauth_key_file_override,
                                       description: "Use this key instead of application default credential",
                                       default_value: nil,
                                       optional: true,
                                       verify_block: proc do |value|
                                         v = File.expand_path(value.to_s)
                                         UI.user_error!("Key file not found at path '#{v}'") unless File.exist?(v)
                                       end)
        ]
      end

      def self.check_has_property(hash_obj, property)
        UI.user_error!("Each device must have #{property} property") unless hash_obj.has_key?(property)
      end
    end
  end
end