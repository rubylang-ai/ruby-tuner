# frozen_string_literal: true

module RubyTuner
  class ModelFineTuner
    def initialize(training_data, base_model_path = nil)
      @training_data = training_data
      @base_model_path = base_model_path || RubyTuner.configuration.base_model_path
    end

    def fine_tune(output_dir, epochs: 3, learning_rate: 2e-5)
      PythonBridge.instance.fine_tune_model(
        @base_model_path,
        @training_data,
        output_dir,
        epochs: epochs,
        learning_rate: learning_rate
      )
    end
  end
end
