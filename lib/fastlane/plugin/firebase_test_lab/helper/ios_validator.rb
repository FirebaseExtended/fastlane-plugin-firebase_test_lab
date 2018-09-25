require 'zip'
require 'nokogiri'

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
              doc = Nokogiri::XML() do |config|
                config.strict.noblanks
              end
            end
          end
        end
      end
    end
  end
end
