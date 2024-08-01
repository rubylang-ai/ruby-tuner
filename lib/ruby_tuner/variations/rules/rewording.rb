# frozen_string_literal: true

module RubyTuner
  module Variations
    module Rules
      class Rewording < Rule
        REWORDINGS = {
          "implement" => ["create", "write", "develop"],
          "method" => ["function", "procedure", "routine"],
          "array" => ["list", "collection", "group"]
        }

        def apply(content, metadata)
          REWORDINGS.each do |original, alternatives|
            if content.include?(original)
              replacement = alternatives.sample
              content = content.gsub(original, replacement)
            end
          end
          content
        end
      end
    end
  end
end
