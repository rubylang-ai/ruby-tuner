# frozen_string_literal: true

require "tf-idf-similarity"
require "narray"

module RubyTuner
  module Adapters
    module Similarity
      class TfIdf < Base
        def calculate_similarity(str1, str2)
          corpus = [
            TfIdfSimilarity::Document.new(str1),
            TfIdfSimilarity::Document.new(str2)
          ]
          model = TfIdfSimilarity::TfIdfModel.new(corpus, library: :narray)
          matrix = model.similarity_matrix
          matrix[0, 1]
        end
      end
    end
  end
end
