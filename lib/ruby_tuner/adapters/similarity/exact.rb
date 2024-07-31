# frozen_string_literal: true

module RubyTuner
  module Adapters
    module Similarity
      class Exact < Base
        def calculate_similarity(str1, str2)
          (str1 == str2) ? 1.0 : 0.0
        end
      end
    end
  end
end
