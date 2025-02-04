# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module RubyTuner
  module Inference
    # Client for interacting with Text Generation Inference API
    class TextGeneration
      # Error raised when API request fails
      class APIError < StandardError; end

      # Default configuration for the TGI client
      DEFAULT_CONFIG = {
        host: "http://127.0.0.1:3000",
        timeout: 30,
        temperature: 0.7,
        max_tokens: 1000
      }.freeze

      # @return [Hash] The configuration for this client
      attr_reader :config

      # Initialize a new TGI client
      #
      # @param config [Hash] Configuration options
      # @option config [String] :host The host URL for the TGI server
      # @option config [Integer] :timeout Request timeout in seconds
      # @option config [Float] :temperature Sampling temperature
      # @option config [Integer] :max_tokens Maximum tokens to generate
      def initialize(config = {})
        @config = DEFAULT_CONFIG.merge(config)
        @uri = URI.parse(File.join(@config[:host], "v1/chat/completions"))
      end

      # Generate a completion for a chat message
      #
      # @param messages [Array<Hash>] The messages to send
      # @return [String] The generated completion
      # @raise [APIError] If the API request fails
      def complete(messages)
        response = make_request(messages)
        parse_response(response)
      rescue StandardError => e
        raise APIError, "API request failed: #{e.message}"
      end

      # Run a feature against the TGI server
      #
      # @param feature_id [String] The ID of the feature to run
      # @return [String] The generated implementation
      # @raise [APIError] If the feature cannot be loaded or the API request fails
      def run_feature(feature_id)
        feature_content = load_feature(feature_id)
        messages = format_messages(feature_content)
        complete(messages)
      end

      private

      def make_request(messages)
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.read_timeout = config[:timeout]

        request = Net::HTTP::Post.new(@uri.path)
        request["Content-Type"] = "application/json"
        request.body = {
          messages: messages,
          temperature: config[:temperature],
          max_tokens: config[:max_tokens]
        }.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise APIError, "HTTP #{response.code}: #{response.message}"
        end

        response
      end

      def parse_response(response)
        result = JSON.parse(response.body)
        result.dig("choices", 0, "message", "content")
      rescue JSON::ParserError => e
        raise APIError, "Failed to parse response: #{e.message}"
      end

      def load_feature(feature_id)
        feature_path = File.join(RubyTuner.configuration.workspace_dir, "features", feature_id, "feature.rb")
        File.read(feature_path)
      rescue Errno::ENOENT
        raise APIError, "Feature not found: #{feature_id}"
      end

      def format_messages(feature_content)
        [
          {
            role: "system",
            content: "You are a Ruby programming assistant. Generate code based on the following feature description."
          },
          {
            role: "user",
            content: feature_content
          }
        ]
      end
    end
  end
end
