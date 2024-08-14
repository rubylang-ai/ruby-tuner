# frozen_string_literal: true

require "pycall/import"
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
  self.configuration ||= Configuration.load

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.setup!
    PythonSetup.configure_environment
    configuration.save!
  end

  def self.setup?
    PythonSetup.valid?
  end

  def self.import_python_module(module_name)
    @python_modules ||= {}
    RubyTuner.logger.debug "Importing python module: '#{module_name}'." unless @python_modules.key?(module_name)
    @python_modules[module_name] ||= PyCall.import_module(module_name)
  end

  def self.python_module(module_name)
    import_python_module(module_name)
  end
end
