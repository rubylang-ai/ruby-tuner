# spec/ruby_tuner/cli_spec.rb

require "spec_helper"
require "ruby_tuner/cli"

RSpec.describe RubyTuner::CLI do
  let(:cli) { described_class.new }

  describe "#evaluate" do
    let(:feature_id) { "test-feature" }
    let(:implementation) { "def hello\n  puts 'Hello, World!'\nend" }
    let(:mock_feature_evaluator) { instance_double(RubyTuner::Evaluators::Feature) }
    let(:mock_similarity_evaluator) { instance_double(RubyTuner::Evaluators::Similarity) }

    before do
      allow(RubyTuner::Evaluators::Similarity).to receive(:new).and_return(mock_similarity_evaluator)
      allow(RubyTuner::Evaluators::Feature).to receive(:new).and_return(mock_feature_evaluator)
      allow(mock_feature_evaluator).to receive(:evaluate)

      # Mock STDIN to provide generated content
      allow($stdin).to receive(:gets).and_return(implementation)
    end

    context "with inline implementation" do
      it "uses the provided implementation" do
        expect(mock_feature_evaluator).to receive(:evaluate).with(implementation)
        cli.evaluate(feature_id, implementation)
      end
    end

    context "with file implementation" do
      let(:file_path) { "/path/to/implementation.rb" }

      before do
        allow(File).to receive(:read).with(file_path).and_return(implementation)
      end

      it "reads the implementation from the file" do
        expect(mock_feature_evaluator).to receive(:evaluate).with(implementation)
        cli.invoke(:evaluate, [feature_id], file: file_path)
      end

      it "raises an error if the file is not found" do
        allow(File).to receive(:read).with(file_path).and_raise(Errno::ENOENT)
        expect { cli.invoke(:evaluate, [feature_id], file: file_path) }.to raise_error(Thor::Error, /File not found/)
      end
    end

    context "with stdin implementation" do
      before do
        allow($stdin).to receive(:tty?).and_return(true)
        allow($stdin).to receive(:gets).and_return(implementation)
      end

      it "reads the implementation from stdin" do
        expect(mock_feature_evaluator).to receive(:evaluate).with(implementation)
        cli.evaluate(feature_id)
      end
    end

    context "with no implementation provided" do
      before do
        allow($stdin).to receive(:tty?).and_return(false)
      end

      it "raises an error" do
        expect { cli.evaluate(feature_id) }.to raise_error(Thor::Error, /No implementation provided/)
      end
    end

    it "creates a Similarity evaluator with default options" do
      expect(RubyTuner::Evaluators::Similarity).to receive(:new).with(
        similarity_method: :tf_idf,
        acceptance_score: 0.8
      )
      cli.evaluate(feature_id, implementation)
    end

    it "creates a Feature evaluator with the given feature_id and Similarity evaluator" do
      expect(RubyTuner::Evaluators::Feature).to receive(:new).with(
        feature_id,
        evaluators: [mock_similarity_evaluator]
      )
      cli.evaluate(feature_id, implementation)
    end

    it "calls evaluate on the Feature evaluator with the generated content" do
      expect(mock_feature_evaluator).to receive(:evaluate).with(implementation)
      cli.evaluate(feature_id, implementation)
    end
  end
end
