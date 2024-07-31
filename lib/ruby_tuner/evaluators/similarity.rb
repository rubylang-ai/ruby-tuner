# frozen_string_literal: true

module RubyTuner
  module Evaluators
    class Similarity < Base
      def initialize(similarity_method: :tf_idf, acceptance_score: 0.8)
        super("Similarity")
        @similarity_adapter = RubyTuner::Adapters::Similarity::AdapterFactory.create(similarity_method, acceptance_score)
      end

      def evaluate(generated_content, expected_content)
        @result = @similarity_adapter.calculate_similarity(generated_content, expected_content)
        logger.debug "Similarity score: #{@result.round(2)}"
        @result
      end

      def pass?
        @similarity_adapter.meets_acceptance_score?(@result)
      end
    end
  end
end
