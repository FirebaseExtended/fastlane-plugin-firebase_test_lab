require 'fastlane_core/configuration/config_item'

module Fastlane
  module FirebaseTestLab
    class Options
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :gcp_project,
                                       description: "Google Cloud Platform project name",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :app_path,
                                       description: "Path to the app, either on the filesystem or GCS address (gs://)",
                                       default_value:
                                         Actions.lane_context[Actions::SharedValues::SCAN_ZIP_BUILD_PRODUCTS_PATH],
                                       optional: true,
                                       verify_block: proc do |value|
                                         unless value.to_s.start_with?("gs://")
                                           v = File.expand_path(value.to_s)
                                           UI.user_error!("App file not found at path '#{v}'") unless File.exist?(v)
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :devices,
                                       description: "Devices to test the app on",
                                       type: Array,
                                       default_value: [{
                                         ios_model_id: "iphonex",
                                         ios_version_id: "11.2",
                                         locale: "en_US",
                                         orientation: "portrait"
                                       }],
                                       verify_block: proc do |value|
                                         if value.empty?
                                           UI.user_error!("Devices cannot be empty")
                                         end
                                         value.each do |current|
                                           UI.user_error!("Each device must be represented by a Hash object, " +
                                             "#{current.class} found") if current.class != Hash
                                           check_has_property(current, :ios_model_id)
                                           check_has_property(current, :ios_version_id)
                                           set_default_property(current, :locale, "en_US")
                                           set_default_property(current, :orientation, "portrait")
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :async,
                                       description: "Do not wait for test results",
                                       default_value: false,
                                       type: Fastlane::Boolean),
          FastlaneCore::ConfigItem.new(key: :timeout_sec,
                                       description: "After how long, in seconds, should tests be terminated",
                                       default_value: 180,
                                       optional: true,
                                       type: Integer,
                                       verify_block: proc do |value|
                                         UI.user_error!("Timeout must be less or equal to 45 minutes.") \
                                           if value <= 0 || value > 45 * 60
                                       end),
          FastlaneCore::ConfigItem.new(key: :result_storage,
                                       description: "GCS path to store test results",
                                       default_value: nil,
                                       optional: true,
                                       verify_block: proc do |value|
                                         UI.user_error!("Invalid GCS path: '#{value}'") \
                                           unless value.to_s.start_with?("gs://")
                                       end),
          FastlaneCore::ConfigItem.new(key: :oauth_key_file_path,
                                       description: "Use the given Google cloud service key file." +\
                                                    "If not set, application default credential will be used " +\
                                                    "(see https://cloud.google.com/docs/authentication/production)",
                                       default_value: nil,
                                       optional: true,
                                       verify_block: proc do |value|
                                         v = File.expand_path(value.to_s)
                                         UI.user_error!("Key file not found at path '#{v}'") unless File.exist?(v)
                                       end),
        ]
      end

      def self.check_has_property(hash_obj, property)
        UI.user_error!("Each device must have #{property} property") unless hash_obj.has_key?(property)
      end

      def self.set_default_property(hash_obj, property, default)
        unless hash_obj.has_key?(property)
          hash_obj[property] = default
        end
      end
    end
  end
end
