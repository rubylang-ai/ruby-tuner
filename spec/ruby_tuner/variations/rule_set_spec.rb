# spec/ruby_tuner/variations/rule_set_spec.rb

require "spec_helper"

# Dummy subclass for testing
class DummyRules < RubyTuner::Variations::RuleSet
  def build_rules(config)
    [DummyRule.new(config[:dummy])]
  end

  def self.default_config
    {dummy: {enabled: true, probability: 1.0}}
  end
end

class DummyRule < RubyTuner::Variations::Rule
  def apply(content, metadata = {})
    "Modified: #{content}" if @config[:enabled]
  end
end

RSpec.describe RubyTuner::Variations::RuleSet do
  let(:workspace_dir) { "tmp/ruby_tuner_test" }
  let(:feature_id) { "test_feature" }
  let(:global_config_path) { File.join(workspace_dir, "config", "dummy.yml") }
  let(:feature_config_path) { File.join(workspace_dir, "features", feature_id, "config.yml") }

  before do
    FileUtils.mkdir_p File.dirname(global_config_path)
    FileUtils.mkdir_p File.dirname(feature_config_path)
    RubyTuner.configure do |config|
      config.workspace_dir = workspace_dir
    end
  end

  after do
    FileUtils.rm global_config_path if File.exist?(global_config_path)
    FileUtils.rm feature_config_path if File.exist?(feature_config_path)
  end

  describe "#initialize" do
    context "when no configs exist" do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it "uses the default global config" do
        rule_set = DummyRules.new
        expect(rule_set.rules.first).to be_a(DummyRule)
        expect(rule_set.rules.first.config).to eq({enabled: true, probability: 1.0})
      end
    end

    context "when global config exists" do
      let(:global_config) { {dummy: {enabled: false, probability: 0.7}} }

      before do
        File.write(global_config_path, global_config.to_yaml)
      end

      it "uses the global config" do
        rule_set = DummyRules.new
        expect(rule_set.rules.first.config).to eq({enabled: false, probability: 0.7})
      end
    end

    context "when feature config exists" do
      let(:global_config) { {dummy: {enabled: false, probability: 0.7}} }
      let(:feature_config) { {dummy: {dummy: {enabled: true, probability: 0.3}}} }

      before do
        File.write(global_config_path, global_config.to_yaml)
        File.write(feature_config_path, feature_config.to_yaml)
      end

      it "merges global and feature configs" do
        rule_set = DummyRules.new(feature_id)
        expect(rule_set.rules.first.config).to eq({enabled: true, probability: 0.3})
      end
    end

    context "with custom global config" do
      let(:custom_global_config) { {dummy: {enabled: true, probability: 0.9}} }

      it "uses the custom global config" do
        rule_set = DummyRules.new(nil, custom_global_config)
        expect(rule_set.rules.first.config).to eq({enabled: true, probability: 0.9})
      end
    end
  end

  describe "#apply" do
    let(:rule_set) { DummyRules.new }
    let(:content) { "Original content" }
    let(:metadata) { {some: "metadata"} }

    it "applies all rules to the content" do
      expect(rule_set.apply(content, metadata)).to eq("Modified: Original content")
    end

    context "when rule is disabled" do
      let(:custom_config) { {dummy: {enabled: false, probability: 0.5}} }
      let(:rule_set) { DummyRules.new(nil, custom_config) }

      it "does not modify the content" do
        expect(rule_set.apply(content, metadata)).to eq("Original content")
      end
    end
  end
end
