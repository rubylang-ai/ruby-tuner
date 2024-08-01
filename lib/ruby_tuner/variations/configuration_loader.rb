# frozen_string_literal: true

require "yaml"

module RubyTuner
  module Variations
    class ConfigurationLoader
      def self.load(rule_set_type, feature_id = nil)
        global_config = load_global_config(rule_set_type)
        return global_config unless feature_id

        feature_config = load_feature_config(feature_id)
        deep_merge(global_config, feature_config[rule_set_type] || {})
      end

      def self.load_global_config(rule_set_type)
        YAML.load_file(File.join(RubyTuner.configuration.workspace_dir, "config", "#{rule_set_type}_config.yml"))
      end

      def self.load_feature_config(feature_id)
        feature_config_path = File.join(RubyTuner.configuration.workspace_dir, "features", feature_id, "config.yml")
        File.exist?(feature_config_path) ? YAML.load_file(feature_config_path) : {}
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
    end
  end
end
