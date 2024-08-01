# frozen_string_literal: true

module RubyTuner
  module Variations
    module Rules
      class Idiom < Rule
        IDIOMS = {
          /(\w+)\.each do \|(\w+)\|/ => '\1.each_with_index do |\2, i|',
          /(\w+)\.map\s*{(.+?)}/ => '\1.map(&\2)',
          /(\w+) = \1 \|\| (.+)/ => '\1 ||= \2'
        }

        def apply(content, metadata)
          IDIOMS.each do |pattern, replacement|
            content = content.gsub(pattern, replacement)
          end
          content
        end
      end
    end
  end
end
