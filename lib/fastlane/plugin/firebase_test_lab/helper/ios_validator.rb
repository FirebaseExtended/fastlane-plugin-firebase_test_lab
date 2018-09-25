require 'zip'
require 'plist'

module Fastlane
  module FirebaseTestLab
    class IosValidator
      def self.validate_ios_app(file_path)
        xctestrun_inspected = false
        Zip::File.open(file_path) do |zip_file|
          zip_file.each do |entry|
            if !entry.name.include?("/") && entry.name.end_with?(".xctestrun")
              if xctestrun_inspected
                UI.user_error!("app verification failed: There could be only one .xctestrun files in the ZIP file.")
              end

              xctestrun_inspected = true
              conf = Plist.parse_xml(entry.get_input_stream)
              unless conf.size == 1
                UI.user_error("The app bundle may contain only one scheme, #{conf.size} found")
              end
              _, scheme_conf = conf.first
              unless scheme_conf["IsUITestBundle"]
                UI.user_error("The app bundle is not a UI test bundle. Did you build with build-for-testing argument?")
              end
              unless scheme_conf.key?("TestHostPath") || scheme_conf.key?("TestBundlePath")
                UI.user_error("Either TestHostPath or TestBundlePath must be in the app bundle. Please check your " \
                              "xcodebuild arguments")
              end
              unless scheme_conf.key?("CFBundleDisplayName") || scheme_conf.key?("CFBundleName")
                UI.user_error("Either CFBundleDisplayName or CFBundleName must be in the app bundle. Please check " \
                              "your xcodebuild arguments")
              end
            end
          end
        end
      end
    end
  end
end
