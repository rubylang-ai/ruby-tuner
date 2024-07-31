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

    desc "evaluate FEATURE_ID [IMPLEMENTATION]", "Evaluate the generated content for a feature"
    method_option :similarity_method, type: :string, default: :tf_idf, desc: "Similarity method to use (tf_idf or exact)"
    method_option :acceptance_score, type: :numeric, default: 0.8, desc: "Similarity score that passes evaluation"
    method_option :file, type: :string, desc: "Path to file containing the implementation"
    def evaluate(feature_id, implementation = nil)
      raise Thor::Error, "Feature ID is required" if feature_id.nil? || feature_id.empty?

      begin
        generated_content = if implementation
          implementation
        elsif options[:file]
          File.read(options[:file])
        elsif $stdin.tty?
          say "Provide an implementation to evaluate:"
          $stdin.gets.strip
        else
          raise Thor::Error, "No implementation provided. Please provide it inline, via a file, or through standard input."
        end
      rescue Errno::ENOENT
        raise Thor::Error, "File not found: #{options[:file]}"
      end

      raise Thor::Error, "No implementation provided" if generated_content.empty?

      # For tests we need to explicitly define defaults
      similarity_method = (options[:similarity_method] || "tf_idf").to_sym
      acceptance_score = options[:acceptance_score] || 0.8

      similarity_evaluator = RubyTuner::Evaluators::Similarity.new(
        similarity_method: similarity_method,
        acceptance_score: acceptance_score
      )

      evaluator = RubyTuner::Evaluators::Feature.new(
        feature_id,
        evaluators: [similarity_evaluator]
      )

      evaluator.evaluate(generated_content)
    end
  end
end
