# frozen_string_literal: true

require "thor"
require_relative "generators/feature"

module RubyTuner
  class CLI < Thor
    package_name "RubyTuner"

    def self.exit_on_failure?
      true
    end

    desc "generate_feature DESCRIPTION", "Generate a feature file"
    long_desc <<-LONGDESC
      Generates a feature file using the given description.

      DESCRIPTION: A string describing the feature.

      --implementation_file option can be used to specify a file containing the implementation code.
      --test_cases option can be used to specify a YAML file with test cases.
      --template option can be used to specify a custom ERB template.
    LONGDESC
    option :implementation, type: :string, desc: "Path to custom implementation file"
    option :test_cases, type: :string, desc: "Path to test cases YAML file"
    option :template, type: :string, desc: "Path to custom template file"
    def generate_feature(description)
      RubyTuner::Generators::Feature.new([description], {
        implementation_file: options[:implementation],
        test_cases_file: options[:test_cases],
        template_file: options[:template]
      }).invoke_all
    end
  end
end
