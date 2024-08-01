# frozen_string_literal: true

require "spec_helper"

# Concrete subclass for testing
class TestRule < RubyTuner::Variations::Rule
  def apply(content, metadata)
    "Transformed: #{content}"
  end
end

RSpec.describe RubyTuner::Variations::Rule do
  let(:config) { {enabled: true, probability: 1.0} }

  subject(:rule) { TestRule.new(config) }

  describe "#apply" do
    let(:content) { "Original content" }
    let(:metadata) { {some: "metadata"} }

    it "transforms the content" do
      expect(rule.apply(content, metadata)).to eq("Transformed: Original content")
    end
  end

  describe "#apply" do
    it "raises NotImplementedError when called on base class" do
      base_rule = described_class.new({})
      expect { base_rule.apply("content", {}) }.to raise_error(NotImplementedError)
    end
  end
end
