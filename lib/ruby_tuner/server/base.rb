# frozen_string_literal: true

module RubyTuner
  module Server
    # Base server class defining common interface for inference servers
    class Base
      # @return [String] path to the model being served
      attr_reader :model_path
      # @return [Hash] server configuration options
      attr_reader :options

      # Initialize a new server instance
      # @param model_path [String] path to the model
      # @param options [Hash] server configuration options
      def initialize(model_path, options = {})
        @model_path = model_path
        @options = options
      end

      # Start the server
      # @raise [NotImplementedError] if not implemented by subclass
      def start
        raise NotImplementedError
      end
    end
  end
end
