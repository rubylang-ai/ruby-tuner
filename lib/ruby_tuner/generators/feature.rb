require "thor/group"
require "yaml"
require "fileutils"
require "tmpdir"
require "active_support/core_ext/string/inflections"

module RubyTuner
  module Generators
    class Feature < Thor::Group
      include Thor::Actions

      DEFAULT_TEMPLATE = File.expand_path("../../templates/feature.erb", __FILE__)

      argument :description, type: :string, desc: "Feature description"

      class_option :implementation_file, type: :string, desc: "Path to the implementation file"
      class_option :test_cases, type: :string, desc: "Path to test cases YAML file"
      class_option :template, type: :string, desc: "Path to custom template file"

      def self.source_root
        File.dirname(__FILE__)
      end

      def set_feature_directory
        @feature_id = description.parameterize
        @feature_dir = File.join(RubyTuner.configuration.workspace_dir, "features", @feature_id)
      end

      def check_existing_feature
        if File.exist?(@feature_dir)
          error_message = <<~ERROR
            Error: A feature with this description already exists.

            Feature directory: #{@feature_dir}

            To update this feature:
            1. Edit the feature description in #{File.join(@feature_dir, "feature.rb")}
            2. Update the implementation in #{File.join(@feature_dir, "implementation.rb")}
            3. Modify test cases in #{File.join(@feature_dir, "test_cases.yml")}

            If you want to create a new feature, please use a different description.
          ERROR
          raise Thor::Error, error_message
        end
      end

      def check_template_file_existence
        raise Thor::Error, "The template file you provided does not exist!" if options[:template] && !File.exist?(options[:template])
      end

      def create_feature_directory
        FileUtils.mkdir_p(@feature_dir)
      end

      def generate_feature_file
        template_content = if options[:template] && File.exist?(options[:template])
          File.read(options[:template])
        else
          File.read(DEFAULT_TEMPLATE)
        end

        erb = ERB.new(template_content, trim_mode: "-")
        @feature_content = erb.result_with_hash(description: description)

        create_file File.join(@feature_dir, "feature.rb"), @feature_content
      end

      def copy_implementation_file
        if options[:implementation_file]
          copy_file options[:implementation_file], File.join(@feature_dir, "implementation.rb")
        else
          create_file File.join(@feature_dir, "implementation.rb"), "# TODO: Implement your implementation here"
        end
      end

      def copy_test_cases_file
        return unless options[:test_cases]

        copy_file options[:test_cases], File.join(@feature_dir, "test_cases.yml")
      end

      def print_next_steps
        say "Feature generated successfully in #{@feature_dir}"
        say "Next steps:"
        say "1. Review and edit the feature description in feature.rb"
        say "2. Implement or refine your implementation in implementation.rb"
        say "3. Add more test cases to test_cases.yml if needed"
        say "4. Generate training data using:"
        say "   ruby_tuner generate_training_data #{@feature_id}"
      end
    end
  end
end
