# frozen_string_literal: true

module RubyTuner
  module Evaluators
    class Composite
      def initialize(evaluators)
        @evaluators = evaluators
      end

      def evaluate(generated_content, expected_content)
        @evaluators.each do |evaluator|
          evaluator.evaluate(generated_content, expected_content)
        end
      end

      def pass?
        @evaluators.all?(&:pass?)
      end

      def status
        pass? ? "PASS" : "FAIL"
      end
    end
  end
end
