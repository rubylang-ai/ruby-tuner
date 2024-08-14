# lib/ruby_tuner/fine_tuning/model_persistence.rb

require "fileutils"
require "json"

module RubyTuner
  module FineTuning
    # Handles saving and loading of fine-tuned models
    class ModelPersistence
      # Initializes a new ModelPersistence instance
      # @param config [RubyTuner::Configuration] the configuration object
      def initialize(config = RubyTuner.configuration)
        @config = config
      end

      # Saves the fine-tuned model, tokenizer, and metadata
      # @param model [Object] the fine-tuned model to save
      # @param tokenizer [Object] the tokenizer used with the model
      # @param output_dir [String] the directory to save the model
      # @param metadata [Hash] additional metadata to save with the model
      def save_model(model, tokenizer, output_dir, metadata = {})
        FileUtils.mkdir_p(output_dir)

        # Save the model
        model_path = File.join(output_dir, "pytorch_model.bin")
        PyCall.eval("torch").save(model.state_dict, model_path)

        # Save the model configuration
        model.config.save_pretrained(output_dir)

        # Save the tokenizer
        tokenizer.save_pretrained(output_dir)

        # Save metadata
        metadata_path = File.join(output_dir, "metadata.json")
        File.write(metadata_path, JSON.pretty_generate(metadata))

        RubyTuner.logger.info("Model, tokenizer, and metadata saved to #{output_dir}")
      end

      # Loads a saved model, tokenizer, and metadata
      # @param model_dir [String] the directory containing the saved model
      # @return [Hash] a hash containing the loaded model, tokenizer, and metadata
      def load_model(model_name, path: nil, device: "cpu")
        model_dir = File.join(RubyTuner.configuration.fine_tuned_models_dir, model_name)
        RubyTuner.logger.debug "Loading model '#{model_name}' from: #{model_dir}..."
        # Load the model
        model = if model_name.include?("t5") || model_name.include?("bart")
          RubyTuner.python_module("transformers").AutoModelForSeq2SeqLM.from_pretrained(model_name).to(device)
        else
          RubyTuner.python_module("transformers").AutoModelForCausalLM.from_pretrained(model_name).to(device)
        end

        # Load the tokenizer
        tokenizer = load_tokenizer(model_name)

        # Load metadata
        metadata_path = File.join(model_dir, "metadata.json")
        metadata = JSON.parse(File.read(metadata_path)) if File.exist?(metadata_path)

        {
          model: model,
          tokenizer: tokenizer,
          data_collator: load_data_collator(model_name: model_name, model: model, tokenizer: tokenizer),
          metadata: metadata
        }
      end

      # Loads the tokenizer for the specified model
      # @param model_name [String] the name or path of the model
      # @return [PyObject] the loaded tokenizer
      def load_tokenizer(model_name, gpu: false)
        tokenizer = RubyTuner.python_module("transformers").AutoTokenizer.from_pretrained(model_name)
        RubyTuner.logger.info("Loaded Python tokenizer for model: #{model_name}")
        tokenizer
      rescue PyCall::PyError => e
        RubyTuner.logger.error("Failed to load Python tokenizer: #{e.message}")
        raise LoadError, "Unable to load tokenizer for model: #{model_name}"
      end

      def load_data_collator(model_name:, model:, tokenizer:)
        if model_is_encoder_decoder?(model_name)
          RubyTuner.python_module("transformers").DataCollatorForSeq2Seq.new(
            tokenizer,
            model: model,
            padding: true,
            return_tensors: "pt"
          )
        else
          RubyTuner.python_module("transformers").DataCollatorForLanguageModeling.new(
            tokenizer: tokenizer,
            mlm: false
          )
        end
      end

      # Lists all saved models
      # @return [Array<String>] an array of model directory names
      def list_models
        Dir.glob(File.join(@config.fine_tuned_models_dir, "*"))
          .select { |f| File.directory?(f) }
          .map { |f| File.basename(f) }
      end

      # Deletes a saved model
      # @param model_name [String] the name of the model to delete
      def delete_model(model_name)
        model_dir = File.join(@config.fine_tuned_models_dir, model_name)
        if Dir.exist?(model_dir)
          FileUtils.rm_rf(model_dir)
          RubyTuner.logger.info("Model #{model_name} deleted successfully")
        else
          RubyTuner.logger.warn("Model #{model_name} not found")
        end
      end

      private

      def model_is_encoder_decoder?(model_name)
        model_name.include?("t5") || model_name.include?("bart")
      end
    end
  end
end
