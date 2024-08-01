# frozen_string_literal: true

module RubyTuner
  module Variations
    class Rule
      attr_reader :config

      def initialize(config)
        @config = config || {}
      end

      def apply(content, metadata = {})
        raise NotImplementedError, "#{self.class} must implement #apply"
      end

      def enabled?
        config[:enabled] == true
      end

      def apply?
        enabled? && rand < (config[:probability] || 1.0)
      end
    end
  end
end
