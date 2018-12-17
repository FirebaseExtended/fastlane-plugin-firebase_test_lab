require 'zip'
require 'plist'

module Fastlane
  module FirebaseTestLab
    class IosValidator
      def self.validate_ios_app(file_path)
        absolute_path = File.expand_path(file_path)
        begin
          Zip::File.open(absolute_path) do |zip_file|
            xctestrun_files = zip_file.glob("*.xctestrun")
            if xctestrun_files.size != 1
              UI.user_error!("app verification failed: There must be only one .xctestrun files in the ZIP file.")
            end

            conf = Plist.parse_xml(xctestrun_files.first.get_input_stream)

            # Ensure we only have one scheme (other than the metadata if that's present)
            size = conf.size
            if conf['__xctestrun_metadata__']
              size -= 1
            end
            unless size == 1
              UI.user_error!("The app bundle may contain only one scheme, #{size} found.")
            end

            # Find the tests scheme that's not the metadata scheme
            scheme_conf = nil
            conf.each do |key, value|
              if scheme_conf.nil? && key != '__xctestrun_metadata__'
                scheme_conf = value
              end
            end

            # Ensure we found the tests scheme
            if scheme_conf.nil?
              UI.user_error!("Failed to find your UI tests scheme in your .xctestrun file.")
            end

            unless scheme_conf["IsUITestBundle"]
              UI.user_error!("The app bundle is not a UI test bundle. Did you build with build-for-testing argument?")
            end
            unless scheme_conf.key?("TestHostPath") || scheme_conf.key?("TestBundlePath")
              UI.user_error!("Either TestHostPath or TestBundlePath must be in the app bundle. Please check your " \
                            "xcodebuild arguments")
            end
          end
        rescue Zip::Error => e
          UI.user_error!("Failed to read the ZIP file #{file_path}: #{e.message}")
        end
      end
    end
  end
end
