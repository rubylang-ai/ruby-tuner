# frozen_string_literal: true

require "pycall/import"

module RubyTuner
  module FineTuning
    # Manages the fine-tuning process using Python's transformers library
    class FineTuner
      include PyCall::Import

      def setup
        PyCall.init(RubyTuner.configuration.python_executable)
        @transformers = PyCall.import_module("transformers")
        @torch = PyCall.import_module("torch")
        @datasets = PyCall.import_module("datasets")
        pyfrom :"sklearn.model_selection", import: :train_test_split
        setup_device
      end

      # Fine-tunes the model
      # @param base_model [String] the name or path of the base model
      # @param preprocessed_data [Hash] the preprocessed training data
      # @param args [Hash] additional fine-tuning arguments
      # @return [PyObject] the fine-tuned model
      def fine_tune(base_model, tokenizer, preprocessed_data, args = {}, gpu: false)
        setup

        @model = base_model
        @tokenizer = tokenizer
        #post_processed_data = post_process_data(preprocessed_data)

        train_dataset, eval_dataset = create_datasets(preprocessed_data)
        training_args = create_training_arguments(args)

        RubyTuner.logger.debug "Train dataset features: #{train_dataset.features}"
        RubyTuner.logger.debug "Eval dataset features: #{eval_dataset.features}"
        trainer = create_trainer(@model, @tokenizer, train_dataset, eval_dataset, training_args)

        # Debug: Test a forward pass
        sample_input = train_dataset[0]
        debug_forward_pass(sample_input)

        trainer.train
        trainer.model
      end

      private

      def setup_device
        return @device = "cpu" if !@torch || @torch.cuda.is_available

        @device = if @torch.backends.mps.is_available && @torch.backends.mps.is_built
          "mps"
        elsif @torch.cuda.is_available
          "cuda"
        else
          "cpu"
        end
      rescue
        @device = "cpu"
      end

      def debug_forward_pass(sample_input)
        RubyTuner.logger.debug "Testing forward pass..."
        RubyTuner.logger.debug "Sample input keys: #{sample_input.keys}"
        begin
          @model.forward(
            input_ids: @torch.tensor([sample_input['input_ids']]),
            attention_mask: @torch.tensor([sample_input['attention_mask']]),
            labels: @torch.tensor([sample_input['labels']])
          )
          RubyTuner.logger.debug "Forward pass successful"
        rescue => e
          RubyTuner.logger.debug "Forward pass failed: #{e.message}"
          RubyTuner.logger.debug "Error backtrace: #{e.backtrace.join("\n")}"
        end
      end

      def post_process_data(preprocessed_data)
        max_length = preprocessed_data.map { |item| item["input_ids"].length }.max

        preprocessed_data.map do |item|
          {
            input_ids: pad_sequence(item["input_ids"], max_length),
            attention_mask: pad_sequence(item["attention_mask"], max_length),
            labels: pad_sequence(item["labels"], max_length, @tokenizer.pad_token_id)
          }
        end
      end

      def pad_sequence(sequence, max_length, pad_value = 0)
        sequence + [pad_value] * (max_length - sequence.length)
      end

      # Creates a dataset from preprocessed data
      # @param preprocessed_data [Hash] the preprocessed training data
      # @return [PyObject] the dataset
      def create_datasets(preprocessed_data)
        # Convert preprocessed_data to a format suitable for datasets.Dataset.from_dict
        train_data, eval_data = split_data(preprocessed_data)

        train_dataset = @datasets.Dataset.from_dict(
          PyCall::Dict.new({
            "input_ids" => train_data.map { |item| item["input_ids"] },
            "attention_mask" => train_data.map { |item| item["attention_mask"] },
            "labels" => train_data.map { |item| item["labels"] }
          })
        )
        eval_dataset = @datasets.Dataset.from_dict(
          PyCall::Dict.new({
            "input_ids" => eval_data.map { |item| item["input_ids"] },
            "attention_mask" => eval_data.map { |item| item["attention_mask"] },
            "labels" => eval_data.map { |item| item["labels"] }
          })
        )

        [train_dataset, eval_dataset]
      end

      def split_data(data, test_size: 0.2, random_state: 42)
        train, test = train_test_split(
          data,
          test_size: test_size,
          random_state: random_state
        )
        [train, test]
      end

      def create_training_arguments(training_args)
        args = training_args.dup
        batch_size = args.delete(:batch_size) || 8
        default_args = {
          output_dir: "./results",
          num_train_epochs: args.delete(:epochs) || 3,
          per_device_train_batch_size: batch_size,
          per_device_eval_batch_size: batch_size,
          warmup_steps: 500,
          weight_decay: 0.01,
          logging_dir: "./logs",
          logging_steps: 10,
          eval_strategy: "epoch",
          save_strategy: "epoch",
          load_best_model_at_end: true,
          use_cpu: @device != "cuda"
        }

        args = default_args.merge(args)

        @transformers.TrainingArguments.new(**args)
      end

      # Creates a trainer for fine-tuning
      # @param model [PyObject] the model to fine-tune
      # @param train_dataset [PyObject] the training dataset
      # @return [PyObject] the trainer
      def create_trainer(model, tokenizer, train_dataset, eval_dataset, training_args)
        data_collator = @transformers.DataCollatorForLanguageModeling.new(tokenizer: tokenizer, mlm: false)
        RubyTuner.logger.debug "Creating Trainer..."
        @transformers.Trainer.new(
          model: model,
          args: training_args,
          train_dataset: train_dataset,
          eval_dataset: eval_dataset,
          tokenizer: tokenizer,
          data_collator: data_collator
        )
      end
    end
  end
end
