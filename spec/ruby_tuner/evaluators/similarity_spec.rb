# spec/ruby_tuner/evaluators/similarity_spec.rb

require "spec_helper"

RSpec.describe RubyTuner::Evaluators::Similarity do
  let(:similarity_method) { :tf_idf }
  let(:acceptance_score) { 0.8 }
  subject(:evaluator) { described_class.new(similarity_method: similarity_method, acceptance_score: acceptance_score) }

  describe "#evaluate" do
    it "calculates similarity between generated and expected content" do
      generated_content = "def hello\n  puts 'Hello, world!'\nend"
      expected_content = "def hello\n  puts 'Hello, Ruby!'\nend"

      result = evaluator.evaluate(generated_content, expected_content)
      expect(result).to be_between(0, 1)
    end

    it "logs the similarity score" do
      generated_content = "def hello\n  puts 'Hello, world!'\nend"
      expected_content = "def hello\n  puts 'Hello, Ruby!'\nend"

      expect(RubyTuner.logger).to receive(:debug).with(/Similarity score: \d+\.\d+/)
      evaluator.evaluate(generated_content, expected_content)
    end
  end

  describe "#pass?" do
    before do
      allow(evaluator.instance_variable_get(:@similarity_adapter)).to receive(:calculate_similarity).and_return(similarity_score)
    end

    context "when similarity is above acceptance score" do
      let(:similarity_score) { 0.9 }

      it "returns true" do
        evaluator.evaluate("content1", "content2")
        expect(evaluator.pass?).to be true
      end
    end

    context "when similarity is below acceptance score" do
      let(:similarity_score) { 0.7 }

      it "returns false" do
        evaluator.evaluate("content1", "content2")
        expect(evaluator.pass?).to be false
      end
    end
  end

  describe "#status" do
    it "returns PASS when passing" do
      allow(evaluator).to receive(:pass?).and_return(true)
      expect(evaluator.status).to eq("PASS")
    end

    it "returns FAIL when not passing" do
      allow(evaluator).to receive(:pass?).and_return(false)
      expect(evaluator.status).to eq("FAIL")
    end
  end
end
