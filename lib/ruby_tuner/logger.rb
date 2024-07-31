# frozen_string_literal: true

require "logger"

module RubyTuner
  class Logger < ::Logger
    COLORS = {
      "FATAL" => :red,
      "ERROR" => :red,
      "WARN" => :orange,
      "INFO" => :yellow,
      "DEBUG" => :white
    }

    def initialize(*args)
      super
    end

    def self.info(message)
      instance.info(message)
    end

    def self.error(message)
      instance.error(message)
    end

    def self.debug(message)
      instance.debug(message)
    end
  end
end
