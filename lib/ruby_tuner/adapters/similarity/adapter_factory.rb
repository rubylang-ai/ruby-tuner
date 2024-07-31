# frozen_string_literal: true

module RubyTuner
  module Adapters
    module Similarity
      class AdapterFactory
        def self.create(method, acceptance_score)
          case method.to_sym
          when :tf_idf
            Similarity::TfIdf.new(acceptance_score)
          when :exact
            Similarity::Exact.new(acceptance_score)
          else
            raise ArgumentError, "Unknown similarity method: #{method}"
          end
        end
      end
    end
  end
end
