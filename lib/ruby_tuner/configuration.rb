# frozen_string_literal: true

module RubyTuner
  class Configuration
    attr_accessor :workspace_dir, :base_model_path, :training_data_dir, :fine_tuned_models_dir, :python_executable

    def initialize
      @workspace_dir = File.join(Dir.pwd, ".ruby-tuner")
      @base_model_path = File.join(@workspace_dir, "base_model")
      @training_data_dir = File.join(@workspace_dir, "training_data")
      @fine_tuned_models_dir = File.join(@workspace_dir, "fine_tuned_models")
      @python_executable = "python3"
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end
  end
end
