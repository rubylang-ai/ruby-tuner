# frozen_string_literal: true

module RubyTuner
  module Variations
    module Rules
      class Abbreviation < Rule
        ABBREVIATIONS = {
          "implement" => "impl",
          "function" => "func",
          "string" => "str",
          "array" => "arr"
        }

        private

        def apply(content, metadata)
          ABBREVIATIONS.each do |full, abbr|
            content = content.gsub(/\b#{full}\b/, abbr)
          end
          content
        end
      end
    end
  end
end
