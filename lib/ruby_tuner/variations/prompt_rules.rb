# frozen_string_literal: true

module RubyTuner
  module Variations
    class PromptRules < RuleSet
      def build_rules(config)
        [
          Rules::Rewording.new(config[:rewording]),
          Rules::Abbreviation.new(config[:abbreviation])
        ]
      end

      def default_config
        {
          rewording: {enabled: true, probability: 0.7},
          abbreviation: {enabled: true, probability: 0.3}
        }
      end
    end
  end
end
