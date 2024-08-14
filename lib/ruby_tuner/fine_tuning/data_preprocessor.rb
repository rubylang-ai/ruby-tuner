# frozen_string_literal: true

require "json"
require "digest/md5"

module RubyTuner
  module FineTuning
    # Prepares training data for fine-tuning code generation models
    class DataPreprocessor
      include PyCall::Import

      # Maximum sequence length for the model input
      MAX_SEQUENCE_LENGTH = 512

      # Initializes a new DataPreprocessor
      # @param tokenizer [Object] the tokenizer to use for preprocessing
      def initialize(tokenizer)
        @tokenizer = tokenizer
      end

      # Preprocesses the training data
      # @param training_data_path [String] path to the JSON file containing training data
      # @return [Array<Hash>] preprocessed training data
      def preprocess(training_data_path, format: :json)
        cache_key = generate_cache_key(training_data_path, format)
        cached_data = load_from_cache(cache_key)
        return cached_data if cached_data

        raw_data = load_training_data(training_data_path, format)
        total = raw_data.size

        preprocessed_data = raw_data.each_with_index.map do |sample, index|
          preprocessed_sample = preprocess_sample(sample)
          progress = ((index + 1).to_f / total * 100).round(2)
          RubyTuner.logger.info("Preprocessing progress: #{progress}%")
          preprocessed_sample
        end

        cache_preprocessed_data(preprocessed_data, cache_key)
        preprocessed_data
      end

      private

      # Generates a cache key based on the training data path and last modified time
      # @param training_data_path [String] path to the training data file
      # @return [String] cache key
      def generate_cache_key(training_data_path, format)
        file_mtime = File.mtime(training_data_path).to_i
        Digest::MD5.hexdigest("#{training_data_path}:#{format}:#{file_mtime}")
      end

      # Loads preprocessed data from cache if available
      # @param cache_key [String] cache key for the preprocessed data
      # @return [Array<Hash>, nil] cached preprocessed data or nil if not found
      def load_from_cache(cache_key)
        cache_file = File.join(RubyTuner.configuration.cache_dir, "#{cache_key}.json")
        JSON.parse(File.read(cache_file)) if File.exist?(cache_file)
      rescue JSON::ParserError, Errno::ENOENT => e
        RubyTuner.logger.warn("Failed to load cached data: #{e.message}")
        nil
      end

      # Loads the training data from a JSON file
      # @param training_data_path [String] path to the JSON file
      # @return [Array<Hash>] raw training data
      def load_training_data(training_data_path, format)
        case format
        when :json
          JSON.parse(File.read(training_data_path))
        when :csv
          require "csv"
          CSV.parse(File.read(training_data_path), headers: true).map(&:to_h)
        when :yaml
          require "yaml"
          YAML.load_file(training_data_path)
        else
          raise ArgumentError, "Unsupported data format: #{format}"
        end
      rescue => e
        raise ArgumentError, "Failed to load training data: #{e.message}"
      end

      # Caches preprocessed data
      # @param preprocessed_data [Array<Hash>] preprocessed training data
      # @param cache_key [String] cache key for the preprocessed data
      def cache_preprocessed_data(preprocessed_data, cache_key)
        cache_dir = RubyTuner.configuration.cache_dir
        FileUtils.mkdir_p(cache_dir)
        cache_file = File.join(cache_dir, "#{cache_key}.json")
        File.write(cache_file, preprocessed_data.to_json)
        RubyTuner.logger.info("Cached preprocessed data to #{cache_file}")
      rescue Errno::ENOENT, IOError => e
        RubyTuner.logger.error("Failed to cache preprocessed data: #{e.message}")
      end

      # Preprocesses a single sample
      # @param sample [Hash] a single training data sample
      # @return [Hash] preprocessed sample
      def preprocess_sample(sample)
        prompt = sample["prompt"]
        implementation = sample["implementation"]

        input_encoding = encode_text(prompt)
        output_encoding = encode_text(implementation)

        {
          input_ids: tensor_to_array(input_encoding[:input_ids]),
          attention_mask: tensor_to_array(input_encoding[:attention_mask]),
          labels: tensor_to_array(output_encoding[:input_ids])  # For causal language modeling, labels are the same as input_ids
        }
      end

      # Encodes text using the tokenizer
      # @param text [String] text to encode
      # @return [Hash] encoded text with input_ids and attention_mask
      def encode_text(text)
        if @tokenizer.respond_to?(:encode_plus)
          encode_with_python_tokenizer(text)
        else
          encode_with_ruby_tokenizer(text)
        end
      end

      def encode_with_python_tokenizer(text)
        encoded = @tokenizer.encode_plus(
          text,
          add_special_tokens: true,
          max_length: MAX_SEQUENCE_LENGTH,
          padding: "max_length",
          truncation: true,
          return_tensors: "pt"
        )

        {
          input_ids: encoded["input_ids"][0],
          attention_mask: encoded["attention_mask"][0]
        }
      end

      def encode_with_ruby_tokenizer(text)
        tokens = @tokenizer.encode(text)
        padded_tokens = tokens[0...MAX_SEQUENCE_LENGTH].fill(@tokenizer.pad_token_id, tokens.length...MAX_SEQUENCE_LENGTH)
        attention_mask = padded_tokens.map { |token| token == @tokenizer.pad_token_id ? 0 : 1 }

        {
          input_ids: padded_tokens,
          attention_mask: attention_mask
        }
      end

      def tensor_to_array(tensor)
        tensor.detach.cpu.numpy.tolist.to_a
      end
    end
  end
end
