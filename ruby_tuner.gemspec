# frozen_string_literal: true

require_relative "lib/ruby_tuner/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-tuner"
  spec.version = RubyTuner::VERSION
  spec.authors = ["Valentino Stoll"]
  spec.email = ["vstoll@doximity.com"]

  spec.summary = "A framework for fine-tuning a Ruby LLM."
  spec.description = "A framework for powering Rubylang.ai: a fine-tuned LLM for Ruby code generation."
  spec.homepage = "https://github.com/rubylang-ai/ruby-tuner"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubylang-ai/ruby-tuner"
  spec.metadata["changelog_uri"] = "https://github.com/rubylang-ai/ruby-tuner/tree/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "thor"
  spec.add_dependency "zeitwerk"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
