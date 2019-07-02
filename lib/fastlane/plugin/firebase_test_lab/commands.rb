module Fastlane
  module Commands
    def self.download_results
      "gsutil -m cp -r"
    end

    def self.download_single_file
      "gsutil -m cp"
    end

    def self.list_object
      "gsutil ls"
    end

    def self.delete_resuls
      "gsutil rm -r"
    end
  end
end