# frozen_string_literal: true

require "spec_helper"
require "ruby_tuner/evaluators/feature"

RSpec.describe RubyTuner::Evaluators::Feature do
  let(:feature_id) { "test-feature" }
  let(:workspace_dir) { "/tmp/ruby_tuner_test" }
  let(:feature_dir) { File.join(workspace_dir, "features", feature_id) }
  let(:implementation_file) { File.join(feature_dir, "implementation.rb") }
  let(:test_cases_file) { File.join(feature_dir, "test_cases.yml") }

  before do
    allow(RubyTuner.configuration).to receive(:workspace_dir).and_return(workspace_dir)
    FileUtils.mkdir_p(feature_dir)
  end

  after do
    FileUtils.rm_rf(workspace_dir)
  end

  subject(:evaluator) { described_class.new(feature_id) }

  describe "#evaluate" do
    let(:generated_content) { "def hello\n  puts 'Hello, World!'\nend" }
    let(:expected_implementation) { "def hello\n  puts 'Hello, Ruby!'\nend" }

    before do
      File.write(implementation_file, expected_implementation)
    end

    context "when there are no test cases" do
      it "performs a basic evaluation" do
        allow(RubyTuner.logger).to receive(:debug)
        expect(RubyTuner.logger).to receive(:warn).with(/No test cases found/)
        expect(RubyTuner.logger).to receive(:info).with(/Basic evaluation/)
        expect(RubyTuner.logger).to receive(:info).with(/Overall:/)

        evaluator.evaluate(generated_content)
      end
    end

    context "when there are test cases" do
      let(:test_cases) do
        [
          {"name" => "Test 1", "input" => "World", "expected" => "Hello, World!"},
          {"name" => "Test 2", "input" => "Ruby", "expected" => "Hello, Ruby!"}
        ]
      end

      before do
        File.write(test_cases_file, test_cases.to_yaml)
      end

      it "evaluates each test case" do
        allow(RubyTuner.logger).to receive(:debug)
        expect(RubyTuner.logger).to receive(:info).with(/Evaluating feature .* with 2 test cases/)
        expect(RubyTuner.logger).to receive(:debug).with(/Test case 1: Test 1/)
        expect(RubyTuner.logger).to receive(:debug).with(/Similarity score: /)
        expect(RubyTuner.logger).to receive(:debug).with(/Test case 2: Test 2/)
        expect(RubyTuner.logger).to receive(:debug).with(/Similarity score: /)
        expect(RubyTuner.logger).to receive(:info).with(/Overall:/).twice

        evaluator.evaluate(generated_content)
      end
    end
  end

  describe "private methods" do
    describe "#load_expected_implementation" do
      context "when implementation file exists" do
        let(:implementation_content) { "def test_method\n  # Test implementation\nend" }

        before do
          File.write(implementation_file, implementation_content)
        end

        it "loads the implementation content" do
          evaluator.send(:load_expected_implementation)
          expect(evaluator.instance_variable_get(:@expected_implementation)).to eq(implementation_content)
        end
      end

      context "when implementation file does not exist" do
        it "logs an error and exits" do
          expect(RubyTuner.logger).to receive(:error).with(/Unable to load implementation file/)
          expect { evaluator.send(:load_expected_implementation) }.to raise_error(SystemExit)
        end
      end
    end

    describe "#load_test_cases" do
      context "when test cases file exists" do
        let(:test_cases) do
          [
            {"name" => "Test 1", "input" => "input1", "expected" => "output1"},
            {"name" => "Test 2", "input" => "input2", "expected" => "output2"}
          ]
        end

        before do
          File.write(test_cases_file, test_cases.to_yaml)
        end

        it "loads the test cases" do
          evaluator.send(:load_test_cases)
          expect(evaluator.instance_variable_get(:@test_cases)).to eq(test_cases)
        end
      end

      context "when test cases file does not exist" do
        it "sets an empty array for test cases" do
          evaluator.send(:load_test_cases)
          expect(evaluator.instance_variable_get(:@test_cases)).to eq([])
        end
      end
    end
  end
end
