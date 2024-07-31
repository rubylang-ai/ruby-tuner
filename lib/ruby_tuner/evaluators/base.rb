# frozen_string_literal: true

module RubyTuner
  module Evaluators
    class Base
      attr_reader :name

      def initialize(name)
        @name = name
        @result = nil
      end

      def evaluate(generated_content, expected_content)
        raise NotImplementedError, "#{self.class} must implement #evaluate"
      end

      def pass?
        raise NotImplementedError, "#{self.class} must implement #pass?"
      end

      def status
        pass? ? "PASS" : "FAIL"
      end

      protected

      def logger
        RubyTuner.logger
      end
    end
  end
end
