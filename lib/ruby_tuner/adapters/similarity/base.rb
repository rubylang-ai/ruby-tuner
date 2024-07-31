# frozen_string_literal: true

module RubyTuner
  module Adapters
    module Similarity
      class Base
        def initialize(acceptance_score)
          @acceptance_score = acceptance_score
        end

        def calculate_similarity(str1, str2)
          raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
        end

        def meets_acceptance_score?(similarity)
          similarity >= @acceptance_score
        end
      end
    end
  end
end
