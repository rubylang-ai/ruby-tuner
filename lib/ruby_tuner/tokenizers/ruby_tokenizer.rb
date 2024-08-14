# frozen_string_literal: true

module RubyTuner
  module Tokenizers
    class RubyTokenizer
      attr_reader :pad_token_id

      def initialize(model_name)
        @model_name = model_name
        @vocab = build_vocab
        @pad_token_id = @vocab["[PAD]"]
      end

      def encode(text)
        text.split(/\s+/).map { |token| @vocab[token.downcase] || @vocab["[UNK]"] }
      end

      def decode(ids)
        ids.map { |id| @vocab.key(id) || "[UNK]" }.join(" ")
      end

      private

      def build_vocab
        # This is a very simple vocabulary. In a real implementation,
        # you"d want a much more comprehensive vocabulary.
        vocab = {}
        ["[PAD]", "[UNK]", "[CLS]", "[SEP]"].each_with_index do |token, index|
          vocab[token] = index
        end
        ("a".."z").each_with_index do |char, index|
          vocab[char] = index + vocab.size
        end
        vocab
      end
    end
  end
end
