# frozen_string_literal: true

require "pycall/import"

module RubyTuner
  module FineTuning
    # Custom error class for configuration-related errors
    class ConfigurationError < StandardError; end

    # Manages the fine-tuning process for Ruby code generation models
    class FineTuningManager
      include PyCall::Import

      # @return [ModelSelector] the model selector instance
      attr_reader :model_selector
      # @return [DataPreprocessor] the data preprocessor instance
      attr_reader :data_preprocessor
      # @return [FineTuner] the fine-tuner instance
      attr_reader :fine_tuner
      # @return [ModelEvaluator] the model evaluator instance
      attr_reader :model_evaluator
      # @return [ModelPersistence] the model persistence instance
      attr_reader :model_persistence
      # @return [Inference] the inference instance
      attr_reader :inference
      attr_reader :tokenizer

      # Initializes a new FineTuningManager
      def initialize
        @model_selector = ModelSelector.new
        @fine_tuner = FineTuner.new
        @model_persistence = ModelPersistence.new
        @inference = Inference.new(@model_persistence)
        init_python_environment
        setup_device
      end

      # Runs the fine-tuning process
      def run_fine_tuning(params)
        loaded_model = load_model(params[:base_model])
        @model = loaded_model[:model]
        @tokenizer = loaded_model[:tokenizer]
        @data_preprocessor = DataPreprocessor.new(@tokenizer)
        @model_evaluator = ModelEvaluator.new(@tokenizer)

        preprocessed_data = @data_preprocessor.preprocess(params[:training_data_path])

        fine_tuning_args = {
          epochs: params[:epochs],
          batch_size: params[:batch_size],
          learning_rate: params[:learning_rate],
          eval_strategy: params[:evaluation_strategy],
          eval_steps: params[:eval_steps],
          output_dir: params[:output_dir]
        }
        # Setup pad token
        if @tokenizer.pad_token.nil?
          if @tokenizer.eos_token.nil?
            @tokenizer.add_special_tokens({"pad_token": "[PAD]"})
            @model.resize_token_embeddings(@tokenizer.vocab_size)
          else
            @tokenizer.pad_token = @tokenizer.eos_token
          end
          @model.config.pad_token_id = @tokenizer.pad_token_id
        end

        fine_tuned_model = @fine_tuner.fine_tune(@model, @tokenizer, preprocessed_data, fine_tuning_args)

        # Split data into train and test sets
        test_data = preprocessed_data.sample(preprocessed_data.size * 0.2)
        evaluation_results = @model_evaluator.evaluate(fine_tuned_model, test_data)

        if evaluation_results[:performance] >= RubyTuner.configuration.minimum_model_performance
          metadata = {
            base_model: selected_model,
            performance: evaluation_results[:performance],
            fine_tuned_date: Time.now.iso8601,
            fine_tuning_params: fine_tuning_args
          }
          @model_persistence.save_model(fine_tuned_model, tokenization, params[:output_dir], metadata)
          RubyTuner.logger.info("Fine-tuning successful. Model saved to #{params[:output_dir]}")
          true
        else
          RubyTuner.logger.warn("Fine-tuning did not meet performance threshold. Model not saved.")
          false
        end
      end

      # Runs inference using the specified model
      # @param model_name [String] name of the model to use for inference
      # @param prompt [String] input prompt for code generation
      # @param max_length [Integer] maximum length of generated code
      # @param num_return_sequences [Integer] number of code sequences to generate
      # @return [Array<String>] generated code sequences
      def run_inference(model_name, prompt, max_length: Inference::MAX_LENGTH, num_return_sequences: 1)
        @inference.load_model(model_name)
        @inference.generate_code(prompt, max_length: max_length, num_return_sequences: num_return_sequences)
      end

      def load_model(model_name)
        RubyTuner.logger.debug "Loading model: #{model_name}"
        @model_persistence.load_model(model_name, device: @device)
      end

      def list_models
        @model_persistence.list_models
      end

      def delete_model(model_name)
        @model_persistence.delete_model(model_name)
      end

      private

      def init_python_environment
        RubyTuner.setup! unless PythonSetup.valid?

        if python_available?
          RubyTuner.import_python_module("transformers")
          RubyTuner.logger.debug "Successfully imported: 'transformers'."
          RubyTuner.import_python_module("torch")
          RubyTuner.logger.debug "Successfully imported: 'torch'."
        end
      end

      def python_available?
        require "pycall/import"
        true
      rescue LoadError
        RubyTuner.logger.warn("PyCall is not available. Falling back to Ruby-based tokenization.")
        false
      end

      def setup_device
        return @device = "cpu" if !RubyTuner.python_module("torch") || RubyTuner.python_module("torch").cuda.is_available

        @device = if RubyTuner.python_module("torch").backends.mps.is_available && RubyTuner.python_module("torch").backends.mps.is_built
          "mps"
        elsif RubyTuner.python_module("torch").cuda.is_available
          "cuda"
        else
          "cpu"
        end
      rescue
        @device = "cpu"
      end

      def load_python_tokenizer(model_name)
        tokenizer = RubyTuner.python_module("transformers").AutoTokenizer.from_pretrained(model_name)
        RubyTuner.logger.info("Loaded Python tokenizer for model: #{model_name}")
        tokenizer
      rescue PyCall::PyError => e
        binding.irb
        RubyTuner.logger.error("Failed to load Python tokenizer: #{e.message}")
        raise LoadError, "Unable to load tokenizer for model: #{model_name}"
      end

      def load_ruby_tokenizer(model_name)
        # Implement a simple Ruby-based tokenizer as a fallback
        # This is a placeholder and should be replaced with a more sophisticated Ruby tokenizer
        RubyTuner.logger.info("Loaded Ruby tokenizer for model: #{model_name}")
        Tokenizers::RubyTokenizer.new(model_name)
      end

      def setup_padding_token
        if @tokenizer.pad_token.nil?
          if @tokenizer.eos_token.nil?
            @tokenizer.add_special_tokens({pad_token: "[PAD]"})
            @model.resize_token_embeddings(@tokenizer.vocab_size)
          else
            @tokenizer.pad_token = @tokenizer.eos_token
          end
          @model.config.pad_token_id = @tokenizer.pad_token_id
        end
      end
    end
  end
end
