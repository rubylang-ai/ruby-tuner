# frozen_string_literal: true

module RubyTuner
  module Variations
    class ImplementationRules < RuleSet
      def build_rules(config)
        [
          Rules::Idiom.new(config[:idiom])
        ]
      end

      def default_config
        {
          idiom: {enabled: true, probability: 0.6}
        }
      end
    end
  end
end
