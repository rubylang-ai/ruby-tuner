# frozen_string_literal: true
#
require "pycall/import"

module RubyTuner
  module FineTuning
    # Handles code generation inference using fine-tuned models
    class Inference
      include PyCall::Import

      # Maximum length of generated sequences
      MAX_LENGTH = 512

      # Initializes a new Inference instance
      # @param model_persistence [ModelPersistence] instance to load models
      def initialize(model_persistence = ModelPersistence.new)
        @model_persistence = model_persistence
        @current_model = nil
        @current_tokenizer = nil
        PyCall.init(RubyTuner.configuration.python_executable)
      end

      # Loads a specific model for inference
      # @param model_name [String] name of the model to load
      def load_model(model_name)
        model_dir = File.join(RubyTuner.configuration.fine_tuned_models_dir, model_name)
        loaded = @model_persistence.load_model(model_dir)
        @current_model = loaded[:model]
        @current_tokenizer = loaded[:tokenizer]
        RubyTuner.logger.info("Loaded model: #{model_name}")
      end

      # Generates code based on the given prompt
      # @param prompt [String] the input prompt for code generation
      # @param max_length [Integer] maximum length of the generated code
      # @param num_return_sequences [Integer] number of code sequences to generate
      # @return [Array<String>] generated code sequences
      def generate_code(prompt, max_length: MAX_LENGTH, num_return_sequences: 1)
        ensure_model_loaded

        input_ids = @current_tokenizer.encode(prompt, return_tensors: "pt")

        pyimport :torch
        output = []
        with torch.no_grad do
          output = @current_model.generate(
            input_ids,
            max_length: max_length,
            num_return_sequences: num_return_sequences,
            no_repeat_ngram_size: 2,
            do_sample: true,
            top_k: 50,
            top_p: 0.95,
            temperature: 0.7
          )
        end

        output.map { |seq| @current_tokenizer.decode(seq, skip_special_tokens: true) }
      end

      private

      def ensure_model_loaded
        raise "No model loaded. Please call load_model first." if @current_model.nil? || @current_tokenizer.nil?
      end
    end
  end
end
