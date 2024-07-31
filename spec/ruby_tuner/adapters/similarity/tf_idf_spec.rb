# frozen_string_literal: true

require "spec_helper"

RSpec.describe RubyTuner::Adapters::Similarity::TfIdf do
  let(:acceptance_score) { 0.8 }
  subject(:adapter) { described_class.new(acceptance_score) }

  describe "#calculate_similarity" do
    it "returns 1.0 for identical strings" do
      expect(adapter.calculate_similarity("hello world", "hello world")).to be_between(1.0, 1.000000001)
    end

    it "returns a value between 0 and 1 for similar strings" do
      similarity = adapter.calculate_similarity("hello world", "hello ruby world")
      expect(similarity).to be_between(0, 1)
    end

    it "returns a lower value for less similar strings" do
      similarity1 = adapter.calculate_similarity("hello world", "hello ruby world")
      similarity2 = adapter.calculate_similarity("hello world", "goodbye cruel world")
      expect(similarity2).to be < similarity1
    end
  end

  describe "#meets_acceptance_score?" do
    it "returns true when similarity is above the acceptance score" do
      expect(adapter.meets_acceptance_score?(0.9)).to be true
    end

    it "returns false when similarity is below the acceptance score" do
      expect(adapter.meets_acceptance_score?(0.7)).to be false
    end

    it "returns true when similarity equals the acceptance score" do
      expect(adapter.meets_acceptance_score?(0.8)).to be true
    end
  end
end
