# frozen_string_literal: true

require "yaml"
require "fileutils"

module RubyTuner
  class Configuration
    attr_accessor :base_model_path, :training_data_dir, :fine_tuned_models_dir, :python_executable,
      :hugging_face_access_token, :cache_dir, :minimum_model_performance
    attr_reader :workspace_dir

    def initialize
      @workspace_dir = File.join(Dir.pwd, ".ruby-tuner")
      @base_model_path = File.join(@workspace_dir, "base_model")
      @training_data_dir = File.join(@workspace_dir, "training_data")
      @fine_tuned_models_dir = File.join(@workspace_dir, "fine_tuned_models")
      @hugging_face_access_token = ENV["HUGGING_FACE_ACCESS_TOKEN"]
      @cache_dir = File.join(@workspace_dir, "cache")
      @minimum_model_performance = 0.7
      @python_executable = nil
    end

    def workspace_dir=(new_workspace_dir)
      @workspace_dir = new_workspace_dir
      @base_model_path = File.join(@workspace_dir, "base_model")
      @training_data_dir = File.join(@workspace_dir, "training_data")
      @fine_tuned_models_dir = File.join(@workspace_dir, "fine_tuned_models")
      @cache_dir = File.join(@workspace_dir, "cache")
    end

    def save!
      # Make sure workspace exists
      FileUtils.mkdir_p @workspace_dir
      File.write(configuration_file, to_yaml)
    end

    def configuration_file
      File.join(@workspace_dir, "config.yml")
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.load
      YAML.load_file(new.configuration_file, permitted_classes: [RubyTuner::Configuration])
    rescue
      RubyTuner.logger.warn "Unable to load configuration from: #{new.configuration_file}"
      new
    end
  end
end
