# frozen_string_literal: true

module RubyTuner
  module Server
    class Factory
      def self.create(model_path, options = {})
        SGLang.new(model_path, options)
      end
    end
  end
end
