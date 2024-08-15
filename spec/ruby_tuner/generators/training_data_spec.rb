# frozen_string_literal: true

require "spec_helper"

def setup_feature(feature_id)
  @feature_dir = File.join(RubyTuner.configuration.workspace_dir, "features", feature_id)
  FileUtils.mkdir_p @feature_dir
  File.write(File.join(@feature_dir, "feature.rb"), "A method that outputs 'Hello, World!'")
  File.write(File.join(@feature_dir, "implementation.rb"), "def sample_method\n  puts 'Hello, World!'\nend")
  File.write(File.join(@feature_dir, "metadata.yml"), {difficulty: "easy", tags: ["sample"]}.to_yaml)
end

RSpec.describe RubyTuner::Generators::TrainingData do
  let(:workspace_dir) { "#{Dir.pwd}/tmp/.ruby-tuner" }
  let(:feature_id) { "sample_feature" }
  let(:num_examples) { 3 }
  let(:custom_config) { {prompt: {rewording: {enabled: false}}} }

  before do
    @original_working_dir = Dir.pwd
    RubyTuner.configure do |config|
      config.workspace_dir = workspace_dir
    end
    setup_feature(feature_id)
  end

  after do
    RubyTuner.configure do |config|
      config.workspace_dir = @original_working_dir
    end
    FileUtils.rm_rf(workspace_dir)
  end

  describe "#create_training_data" do
    let(:generator) do
      described_class.new
    end

    let(:variator) { instance_double(RubyTuner::Variations::FeatureVariator) }

    it "generates 50 examples by default" do
      generator.invoke_all

      expect(
        JSON.parse(File.read(File.join(RubyTuner.configuration.training_data_dir, "training_data.json"))).size
      ).to eq(50)
    end

    context "when feature_id is specified" do
      let(:generator) { described_class.new([feature_id]) }
      it "generates the training_data.json for the specific feature" do
        generator.invoke_all

        expect(
          JSON.parse(File.read(File.join(RubyTuner.configuration.training_data_dir, feature_id, "training_data.json"))).size
        ).to eq(50)
      end
    end

    context "when output_dir is specified" do
      let(:generator) { described_class.new([feature_id], {output_dir: File.join(workspace_dir, "custom_training")}) }
      it "generates the training_data.json in the specified output directory" do
        generator.invoke_all

        expect(
          File.exist?(File.join(workspace_dir, "custom_training", "training_data.json"))
        ).to be_truthy
      end
    end

    context "when config is specified" do
      let(:generator) { described_class.new([feature_id], {config: custom_config}) }

      it "passes custom configuration to FeatureRules" do
        allow(RubyTuner::Variations::FeatureRules).to receive(:new).and_call_original
        expect(RubyTuner::Variations::FeatureRules).to receive(:new).with(feature_id, custom_config)
        generator.invoke_all
      end
    end

    context "when examples is specified" do
      let(:generator) { described_class.new([], {examples: 1}) }
      it "generates the specified number of variations" do
        generator.invoke_all

        expect(
          JSON.parse(File.read(File.join(RubyTuner.configuration.training_data_dir, "training_data.json"))).size
        ).to eq(1)
      end
    end
  end

  context "when feature does not exist" do
    let(:generator) { described_class.new(["non_existent_feature"]) }

    it "raises an error" do
      expect { generator.invoke_all }.to raise_error(Thor::Error, /Feature not found/)
    end
  end
end
