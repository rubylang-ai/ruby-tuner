# frozen_string_literal: true

module RubyTuner
  module Variations
    class FeatureRules < RuleSet
      def initialize(feature_id, custom_config = nil)
        super
        @prompt_rules = PromptRules.new(feature_id, custom_config&.dig(:prompt))
        @implementation_rules = ImplementationRules.new(feature_id, custom_config&.dig(:implementation))
      end

      def self.default_config
        {
          prompt: PromptRules.default_config,
          implementation: ImplementationRules.default_config
        }
      end

      def build_rules(config)
        [] # delegated to PromptRules and ImplementationRules
      end

      def apply(content, metadata = {})
        {
          prompt: @prompt_rules.apply(content[:prompt], metadata),
          implementation: @implementation_rules.apply(content[:implementation], metadata)
        }
      end
    end
  end
end
