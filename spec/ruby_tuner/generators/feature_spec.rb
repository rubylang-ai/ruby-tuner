# spec/ruby_tuner/generators/feature_spec.rb
require "spec_helper"
require "ruby_tuner/generators/feature"

RSpec.describe RubyTuner::Generators::Feature do
  let(:description) { "Sort an array using the b-tree algorithm" }
  let(:implementation_file) { "#{Dir.pwd}/spec/fixtures/implementation.rb" }
  let(:test_cases_file) { "#{Dir.pwd}/spec/fixtures/test_cases.yml" }
  let(:template_file) { "#{Dir.pwd}/spec/fixtures/custom_template.erb" }
  let(:original_dir) { Dir.pwd }
  let(:workspace_dir) { "#{Dir.pwd}/tmp/.ruby-tuner" }

  before do
    @original_working_dir = Dir.pwd
    RubyTuner.configure do |config|
      config.workspace_dir = workspace_dir
    end
  end

  after do
    RubyTuner.configure do |config|
      config.workspace_dir = @original_working_dir
    end
    FileUtils.rm_rf(workspace_dir)
  end

  describe "#generate_feature_file" do
    it "generates a feature file with implementation and test_cases" do
      generator = described_class.new([description], {implementation_file: implementation_file, test_cases: test_cases_file})

      expect(generator).to receive(:create_file).with(
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/feature.rb",
        an_instance_of(String)
      )
      expect(generator).to receive(:copy_file).with(
        implementation_file,
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/implementation.rb"
      )
      expect(generator).to receive(:copy_file).with(
        test_cases_file,
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/test_cases.yml"
      )

      expect do
        generator.invoke_all
      end.to output(/Feature generated successfully/).to_stdout
    end

    it "generates a feature file with empty implementation" do
      generator = described_class.new([description])

      expect(generator).to receive(:create_file).with(
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/feature.rb",
        an_instance_of(String)
      )
      expect(generator).to receive(:create_file).with(
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/implementation.rb",
        an_instance_of(String)
      )

      expect do
        generator.invoke_all
      end.to output(/Feature generated successfully/).to_stdout
    end

    it "uses a custom template when provided" do
      generator = described_class.new([description], {template: template_file})

      expect(generator).to receive(:create_file).with(
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/feature.rb",
        "Custom Feature: #{description}\n"
      )
      expect(generator).to receive(:create_file).with(
        "#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm/implementation.rb",
        "# TODO: Implement your implementation here"
      )

      expect do
        generator.invoke_all
      end.to output(/Feature generated successfully/).to_stdout
    end

    it "raises an error when the custom template does not exist" do
      custom_template_path = "custom_template.erb"
      generator = described_class.new([description], {implementation_file: implementation_file, test_cases: test_cases_file, template: custom_template_path})

      expect do
        generator.invoke_all
      end.to raise_error(Thor::Error, /The template file you provided does not exist!/)
    end

    it "raises an error when the feature already exists" do
      FileUtils.mkdir_p("#{workspace_dir}/features/sort-an-array-using-the-b-tree-algorithm")

      generator = described_class.new([description], {implementation_file: implementation_file, test_cases: test_cases_file})

      expect do
        generator.invoke_all
      end.to raise_error(Thor::Error, /A feature with this description already exists/)
    end
  end
end
