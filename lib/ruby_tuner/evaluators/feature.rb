# frozen_string_literal: true

require "yaml"

module RubyTuner
  module Evaluators
    class Feature
      attr_reader :feature_id

      def initialize(feature_id, evaluators: nil)
        @feature_id = feature_id
        @feature_dir = File.join(RubyTuner.configuration.workspace_dir, "features", feature_id)
        @evaluators = evaluators || default_evaluators
        @evaluator_composite = Composite.new(@evaluators)
      end

      def evaluate(generated_content)
        load_expected_implementation
        load_test_cases

        if @test_cases.empty?
          logger.warn "No test cases found for feature '#{feature_id}'. Performing basic evaluation."
          basic_evaluation(generated_content)
        else
          run_test_cases(generated_content)
        end
      end

      private

      def logger
        RubyTuner.logger
      end

      def default_evaluators
        [Similarity.new]
      end

      def load_expected_implementation
        implementation_file = File.join(@feature_dir, "implementation.rb")
        @expected_implementation = File.read(implementation_file)
      rescue => e
        logger.error "Unable to load implementation file for feature '#{feature_id}': #{e.message}"
        exit 1
      end

      def load_test_cases
        test_cases_file = File.join(@feature_dir, "test_cases.yml")
        @test_cases = File.exist?(test_cases_file) ? YAML.load_file(test_cases_file) : []
      rescue => e
        logger.error "Error loading test cases: #{e.message}"
        @test_cases = []
      end

      def basic_evaluation(generated_content)
        logger.info "Basic evaluation for feature '#{feature_id}':"
        @evaluator_composite.evaluate(generated_content, @expected_implementation)
        logger.info "Overall: #{@evaluator_composite.status}"
      end

      def run_test_cases(generated_content)
        logger.info "Evaluating feature '#{feature_id}' with #{@test_cases.size} test cases:"

        @test_cases.each_with_index do |test_case, index|
          logger.debug "Test case #{index + 1}: #{test_case["name"]}"

          begin
            @evaluator_composite.evaluate(generated_content, @expected_implementation)

            @evaluators.each do |evaluator|
              logger.debug "  #{evaluator.name}: #{evaluator.status}"
            end

            logger.info "  Overall: #{@evaluator_composite.status}"
          rescue => e
            logger.error "Error during evaluation: #{e.message}"
          end
        end
      end
    end
  end
end
