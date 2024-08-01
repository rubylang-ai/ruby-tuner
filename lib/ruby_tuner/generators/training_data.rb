# frozen_string_literal: true

require "thor/group"
require "json"
require "yaml"
require "fileutils"

module RubyTuner
  module Generators
    # Generates and manages training data based on existing features
    class TrainingData < Thor::Group
      include Thor::Actions

      argument :feature_id, type: :string, required: false, desc: "Feature ID to generate training data for"

      class_option :examples, type: :numeric, default: 50, desc: "Number of examples to generate"
      class_option :output_dir, type: :string, desc: "Custom output directory for training data"
      class_option :config, type: :hash, default: {}, desc: "Custom configuration for rules"

      def self.source_root
        File.dirname(__FILE__)
      end

      def create_training_data
        if feature_id
          generate(feature_id, options[:examples])
        else
          generate_all(options[:examples])
        end
      end

      private

      # Generate training data for a specific feature
      #
      # @param target_feature_id [String] The ID of the feature to generate training data for
      # @param num_examples_per_feature [Integer] The number of examples to generate
      # @return [Array<Hash>] An array of generated training data examples
      def generate(target_feature_id, num_examples_per_feature)
        feature = load_feature(target_feature_id)
        variator = Variations::FeatureVariator.new(feature, Variations::FeatureRules.new(target_feature_id, options[:config]))
        variations = variator.create_variations(num_examples_per_feature)

        save_training_data(variations, target_feature_id)
        variations
      end

      # Generate training data for all features
      #
      # @param num_examples_per_feature [Integer] The number of examples to generate per feature
      # @return [Hash] A hash of feature IDs to their generated training data examples
      def generate_all(num_examples_per_feature)
        feature_ids = Dir.glob(File.join(features_dir, "*")).map { |f| File.basename(f) }

        results = {}
        feature_ids.each do |target_feature_id|
          results[target_feature_id] = generate(target_feature_id, num_examples_per_feature)
        end

        save_training_data(results.values.flatten)
      end

      # Combine training data from multiple features
      #
      # @param feature_ids [Array<String>] The IDs of the features to combine
      # @return [Array<Hash>] Combined training data
      def combine_training_data(feature_ids)
        feature_ids.flat_map do |target_feature_id|
          load_training_data(target_feature_id)
        end.shuffle
      end

      def load_feature(target_feature_id)
        feature_path = File.join(features_dir, target_feature_id)
        {
          id: target_feature_id,
          prompt: File.read(File.join(feature_path, "feature.rb")),
          implementation: File.read(File.join(feature_path, "implementation.rb")),
          metadata: load_metadata(feature_path)
        }
      rescue Errno::ENOENT
        raise Thor::Error, "Feature not found: #{target_feature_id}"
      end

      def load_metadata(feature_path)
        metadata_path = File.join(feature_path, "metadata.yml")
        File.exist?(metadata_path) ? YAML.load_file(metadata_path) : {}
      end

      # Load training data for a specific feature
      #
      # @param target_feature_id [String] The ID of the feature
      # @return [Array<Hash>] The loaded training data
      def load_training_data(target_feature_id)
        file_path = File.join(@training_data_dir, target_feature_id, "training_data.json")
        JSON.parse(File.read(file_path))
      rescue Errno::ENOENT
        RubyTuner.logger.warn("No training data found for feature: #{target_feature_id}")
        []
      end

      def save_training_data(data, target_feature_id = nil)
        output_dir = options[:output_dir] ||
          (target_feature_id ? File.join(training_data_dir, target_feature_id) : training_data_dir)
        FileUtils.mkdir_p(output_dir)

        File.write(
          File.join(output_dir, "training_data.json"),
          JSON.pretty_generate(data)
        )

        say "Training data generated successfully in #{output_dir}", :green
      end

      def features_dir
        File.join(RubyTuner.configuration.workspace_dir, "features")
      end

      def training_data_dir
        RubyTuner.configuration.training_data_dir
      end
    end
  end
end
