# # frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyTuner::Adapters::Similarity::Exact do
  let(:acceptance_score) { 1.0 }
  subject(:adapter) { described_class.new(acceptance_score) }

  describe "#calculate_similarity" do
    it "returns 1.0 for identical strings" do
      expect(adapter.calculate_similarity("hello world", "hello world")).to eq(1.0)
    end

    it "returns 0.0 for different strings" do
      expect(adapter.calculate_similarity("hello world", "hello ruby")).to eq(0.0)
    end
  end

  describe "#meets_acceptance_score?" do
    it "returns true when similarity is 1.0" do
      expect(adapter.meets_acceptance_score?(1.0)).to be true
    end

    it "returns false when similarity is 0.0" do
      expect(adapter.meets_acceptance_score?(0.0)).to be false
    end
  end
end
