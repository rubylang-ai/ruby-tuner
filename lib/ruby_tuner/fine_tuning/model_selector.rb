# frozen_string_literal: true

require "net/http"
require "json"

module RubyTuner
  module FineTuning
    # Handles the selection of base models for fine-tuning
    class ModelSelector
      # Base URL for Hugging Face API
      HF_API_BASE_URL = "https://huggingface.co/api"

      # List of recommended model names for code generation
      RECOMMENDED_MODELS = [
        "microsoft/CodeGPT-small-py",
        "Salesforce/CodeT5-small",
        "bigcode/starcoderbase-1b",
        "facebook/incoder-1B",
        "HuggingFaceTB/SmolLM-135M"
      ].freeze

      # Initializes a new ModelSelector
      def initialize
        @api_token = RubyTuner.configuration.hugging_face_access_token
        validate_api_token
      end

      # Selects a base model for fine-tuning
      # @param model_name [String, nil] name of the model to use, if specified
      # @return [String] the selected model name
      def select_model(model_name = nil)
        if model_name
          validate_model(model_name)
        else
          select_from_recommended_models
        end
      end

      # Lists available models for code generation
      # @return [Array<Hash>] list of available models with their details
      def list_available_models
        response = make_api_request("/models?filter=code-generation")
        JSON.parse(response.body)
      end

      private

      # Validates the presence of the Hugging Face API token
      # @raise [ConfigurationError] if the API token is not set
      def validate_api_token
        return if @api_token

        raise ConfigurationError, <<~ERROR
          Hugging Face API token is not configured.

          Please follow these steps to configure your token:
          1. Generate a token at https://huggingface.co/settings/tokens
          2. Set the token in your environment (HUGGING_FACE_ACCESS_TOKEN) or in your RubyTuner configuration:

             RubyTuner.configure do |config|
               config.hugging_face_access_token = 'your_token_here'
             end

          Ensure this configuration is set before initializing ModelSelector.
        ERROR
      end

      # Validates if the given model exists and is suitable for code generation
      # @param model_name [String] name of the model to validate
      # @return [String] the validated model name
      # @raise [ArgumentError] if the model is not found or not suitable
      def validate_model(model_name)
        response = make_api_request("/models/#{model_name}")
        model_info = JSON.parse(response.body)

        unless model_info["pipeline_tag"] == "text-generation" || model_info["tags"].include?("code-generation")
          raise ArgumentError, "The specified model is not suitable for code generation"
        end

        model_name
      rescue JSON::ParserError, Net::HTTPClientError
        RubyTuner.logger.error("Error validating model: #{e.message}")
        RubyTuner.logger.info("The specified model may not be publicly available or may require authentication.")
        RubyTuner.logger.info("Please check the model name and your permissions, or try a different model.")
        raise ArgumentError, "The specified model was not found"
      end

      # Selects a model from the recommended list
      # @return [String] the selected model name
      def select_from_recommended_models
        puts "Please select a base model for fine-tuning:"
        RECOMMENDED_MODELS.each_with_index do |model, index|
          puts "#{index + 1}. #{model}"
        end

        choice = nil
        until (1..RECOMMENDED_MODELS.size).cover?(choice)
          print "Enter your choice (1-#{RECOMMENDED_MODELS.size}): "
          choice = gets.chomp.to_i
        end

        RECOMMENDED_MODELS[choice - 1]
      end

      # Makes an API request to the Hugging Face API
      # @param endpoint [String] the API endpoint
      # @return [Net::HTTPResponse] the API response
      def make_api_request(endpoint)
        uri = URI.parse("#{HF_API_BASE_URL}#{endpoint}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.request_uri)
        request["Authorization"] = "Bearer #{@api_token}"

        http.request(request)
      end
    end
  end
end
