# frozen_string_literal: true

module RubyTuner
  module Variations
    # Creates variations of features for training data generation
    class FeatureVariator
      GLOBAL_CONFIG_PATH = File.join(RubyTuner.configuration.workspace_dir, "config", "features_config.yml")
      DEFAULT_GLOBAL_CONFIG = {
        prompt: {
          rewording: {enabled: true, probability: 0.7},
          abbreviation: {enabled: true, probability: 0.3},
          context: {enabled: true, probability: 0.5}
        },
        implementation: {
          idiom: {enabled: true, probability: 0.6},
          structure: {enabled: true, probability: 0.4},
          naming: {enabled: true, probability: 0.5}
        }
      }

      def initialize(feature, rule_set = nil)
        @feature = feature
        @rule_set = rule_set || FeatureRules.new(feature[:id])
      end

      def create_variations(num_variations)
        num_variations.times.map do
          content = {
            prompt: @feature[:prompt],
            implementation: @feature[:implementation]
          }
          @rule_set.apply(content, @feature[:metadata])
        end
      end
    end
  end
end
