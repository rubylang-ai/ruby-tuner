# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyTuner::Variations::FeatureVariator do
  let(:feature_id) { "sample_feature" }
  let(:feature) do
    {
      id: feature_id,
      prompt: "Implement a method to reverse a string",
      implementation: "def reverse_string(str)\n  str.reverse\nend",
      metadata: {difficulty: "easy", tags: ["string", "basic"]}
    }
  end

  let(:feature_rules) { instance_double(RubyTuner::Variations::FeatureRules) }

  before do
    allow(RubyTuner::Variations::FeatureRules).to receive(:new).and_return(feature_rules)
    allow(feature_rules).to receive(:apply).and_return({
      prompt: "Write a function to reverse a given string",
      implementation: "def reverse_string(str)\n  str.chars.reduce(&:prepend)\nend"
    })
  end

  describe "#create_variations" do
    subject(:variator) { described_class.new(feature) }

    it "creates the specified number of variations" do
      variations = variator.create_variations(3)
      expect(variations.length).to eq(3)
    end

    it "applies the feature rules to create variations" do
      expect(feature_rules).to receive(:apply).exactly(3).times
      variator.create_variations(3)
    end

    it "returns variations with modified prompt and implementation" do
      variations = variator.create_variations(1)
      expect(variations.first[:prompt]).to eq("Write a function to reverse a given string")
      expect(variations.first[:implementation]).to include("def reverse_string(str)")
      expect(variations.first[:implementation]).to include("str.chars.reduce(&:prepend)")
    end
  end

  context "with custom rule set" do
    let(:custom_rule_set) { instance_double(RubyTuner::Variations::RuleSet) }
    subject(:variator) { described_class.new(feature, custom_rule_set) }

    before do
      allow(custom_rule_set).to receive(:apply).and_return({
        prompt: "Custom prompt variation",
        implementation: "Custom implementation variation"
      })
    end

    it "uses the provided custom rule set" do
      expect(custom_rule_set).to receive(:apply).once
      variator.create_variations(1)
    end

    it "returns variations created by the custom rule set" do
      variations = variator.create_variations(1)
      expect(variations.first[:prompt]).to eq("Custom prompt variation")
      expect(variations.first[:implementation]).to eq("Custom implementation variation")
    end
  end
end
