# frozen_string_literal: true

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.setup

module RubyTuner
  class Error < StandardError; end

  class << self
    attr_accessor :logger, :configuration
  end

  self.logger ||= Logger.new($stdout, level: :debug, progname: "RubyTuner")
  self.configuration ||= Configuration.new

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end
end
