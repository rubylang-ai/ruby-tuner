# frozen_string_literal: true

require "yaml"
require "active_support/core_ext/string/inflections"

module RubyTuner
  module Variations
    class RuleSet
      attr_reader :rules, :config

      def initialize(feature_id = nil, custom_global_config = nil)
        @config = load_configuration(feature_id, custom_global_config)
        @rules = build_rules(@config)
      end

      def apply(content, metadata = {})
        rules.reduce(content) do |modified_content, rule|
          rule.apply? ? rule.apply(modified_content, metadata) : modified_content
        end
      end

      def self.default_config
        {}
      end

      def self.deep_merge(hash1, hash2)
        hash1.merge(hash2) do |key, oldval, newval|
          if oldval.is_a?(Hash) && newval.is_a?(Hash)
            deep_merge(oldval, newval)
          else
            newval
          end
        end
      end

      private

      def load_configuration(feature_id, custom_global_config)
        global_config = custom_global_config || load_global_ruleset_config
        return global_config unless feature_id

        feature_config = load_feature_config(feature_id)
        RuleSet.deep_merge(global_config, feature_config)
      end

      def load_global_config
        config_path = File.join(RubyTuner.configuration.workspace_dir, "config", "#{config_name}.yml")
        File.exist?(config_path) ? YAML.load_file(config_path) : self.class.default_config
      end

      def load_global_ruleset_config
        config_path = File.join(RubyTuner.configuration.workspace_dir, "config", "#{config_name}.yml")
        File.exist?(config_path) ? YAML.load_file(config_path) : load_global_config
      end

      def load_feature_config(feature_id)
        feature_config_path = File.join(RubyTuner.configuration.workspace_dir, "features", feature_id, "config.yml")
        feature_config = File.exist?(feature_config_path) ? YAML.load_file(feature_config_path) : {}
        feature_config[config_name] || {}
      end

      def config_name
        self.class.name.demodulize.underscore.sub(/_rules$/, "").to_sym
      end

      def build_rules(config)
        raise NotImplementedError, "#{self.class} must implement #build_rules"
      end
    end
  end
end
