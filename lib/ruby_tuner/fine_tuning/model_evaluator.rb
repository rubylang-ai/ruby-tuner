# frozen_string_literal: true

module RubyTuner
  module FineTuning
    # Evaluates the performance of fine-tuned models
    class ModelEvaluator
      # Initializes a new ModelEvaluator
      # @param tokenizer [Object] the tokenizer used for the model
      def initialize(tokenizer)
        @tokenizer = tokenizer
      end

      # Evaluates the model's performance
      # @param model [Object] the fine-tuned model to evaluate
      # @param test_data [Array<Hash>] the test data for evaluation
      # @return [Hash] evaluation results including performance metrics
      def evaluate(model, test_data)
        total_samples = test_data.size
        correct_predictions = 0

        test_data.each do |sample|
          input_ids = sample[:input_ids]
          target_ids = sample[:labels]

          # Generate predictions
          output = generate_prediction(model, input_ids)
          predicted_ids = output[:logits].argmax(axis: -1).to_a

          # Compare predictions with targets
          correct_predictions += 1 if predicted_ids == target_ids
        end

        accuracy = correct_predictions.to_f / total_samples

        {
          accuracy: accuracy,
          performance: accuracy  # You might want to use a more complex metric here
        }
      end

      private

      # Generates a prediction from the model
      # @param model [Object] the fine-tuned model
      # @param input_ids [Array<Integer>] input token IDs
      # @return [Hash] model output
      def generate_prediction(model, input_ids)
        input_tensor = PyCall.eval("torch").tensor([input_ids])
        model.generate(input_tensor, max_length: 512)
      end
    end
  end
end
