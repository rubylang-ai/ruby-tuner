# frozen_string_literal: true

require "thor"
require_relative "generators/feature"

module RubyTuner
  class CLI < Thor
    package_name "RubyTuner"

    def self.exit_on_failure?
      true
    end

    desc "setup", "Set up the Python environment for RubyTuner"
    long_desc <<-LONGDESC
      Sets up the Python environment required for RubyTuner.
      This command will check for an existing valid Python installation
      or install a new one if necessary. It also ensures that all required
      Python libraries are available.

      Use this command if you're setting up RubyTuner for the first time
      or if you're experiencing issues with the Python environment.
    LONGDESC
    option :force, type: :boolean, default: false, desc: "Force setup even if a valid environment is detected"
    def setup
      if options[:force]
        say "Forcing Python environment setup...", :blue
        RubyTuner.setup!
      elsif !RubyTuner.setup?
        say "Setting up Python environment...", :blue
        RubyTuner.setup!
      end

      # Double check that the installation went well.
      if RubyTuner.setup?
        say "Python environment is set up and ready!", :green
      else
        say "Failed to set up Python environment. Please check the logs for more information.", :red
      end
    rescue RubyTuner::PythonSetup::PythonNotInstalledError
      say "Failed to set up Python environment. Please check the logs for more information.", :red
    end

    desc "generate_feature DESCRIPTION", "Generate a feature file"
    long_desc <<-LONGDESC
      Generates a feature file using the given description.

      DESCRIPTION: A string describing the feature.

      --implementation_file option can be used to specify a file containing the implementation code.
      --test_cases option can be used to specify a YAML file with test cases.
      --template option can be used to specify a custom ERB template.
    LONGDESC
    option :implementation, type: :string, desc: "Path to custom implementation file"
    option :test_cases, type: :string, desc: "Path to test cases YAML file"
    option :template, type: :string, desc: "Path to custom template file"
    def generate_feature(description)
      RubyTuner::Generators::Feature.new([description], {
        implementation_file: options[:implementation],
        test_cases_file: options[:test_cases],
        template_file: options[:template]
      }).invoke_all
    end

    desc "evaluate FEATURE_ID [IMPLEMENTATION]", "Evaluate the generated content for a feature"
    method_option :similarity_method, type: :string, default: :tf_idf, desc: "Similarity method to use (tf_idf or exact)"
    method_option :acceptance_score, type: :numeric, default: 0.8, desc: "Similarity score that passes evaluation"
    method_option :file, type: :string, desc: "Path to file containing the implementation"
    def evaluate(feature_id, implementation = nil)
      raise Thor::Error, "Feature ID is required" if feature_id.nil? || feature_id.empty?

      begin
        generated_content = if implementation
          implementation
        elsif options[:file]
          File.read(options[:file])
        elsif $stdin.tty?
          say "Provide an implementation to evaluate:"
          $stdin.gets.strip
        else
          raise Thor::Error, "No implementation provided. Please provide it inline, via a file, or through standard input."
        end
      rescue Errno::ENOENT
        raise Thor::Error, "File not found: #{options[:file]}"
      end

      raise Thor::Error, "No implementation provided" if generated_content.empty?

      # For tests we need to explicitly define defaults
      similarity_method = (options[:similarity_method] || "tf_idf").to_sym
      acceptance_score = options[:acceptance_score] || 0.8

      similarity_evaluator = RubyTuner::Evaluators::Similarity.new(
        similarity_method: similarity_method,
        acceptance_score: acceptance_score
      )

      evaluator = RubyTuner::Evaluators::Feature.new(
        feature_id,
        evaluators: [similarity_evaluator]
      )

      evaluator.evaluate(generated_content)
    end

    desc "generate_training_data [FEATURE_ID]", "Generate training data for a feature or all features"
    long_desc <<-LONGDESC
      Generates training data based on the specified feature or all features if no feature ID is provided.

      With FEATURE_ID argument:
      Generates training data for the specified feature.

      Without FEATURE_ID argument:
      Generates training data for all features.

      Options:
      --examples: Number of examples to generate per feature (default: 50)
      --output-dir: Custom output directory for training data
      --config: Path to custom configuration file for rules
    LONGDESC
    option :examples, type: :numeric, default: 50, desc: "Number of examples to generate per feature"
    option :output_dir, type: :string, desc: "Custom output directory for training data"
    option :config, type: :string, desc: "Path to custom configuration file for rules"
    def generate_training_data(feature_id = nil)
      args = feature_id ? [feature_id] : []
      training_options = options.dup
      training_options[:examples] ||= 50
      Generators::TrainingData.new(args, training_options).invoke_all
    rescue Thor::Error => e
      say e.message, :red
      exit 1
    end

    desc "fine_tune BASE_MODEL", "Fine-tune a model"
    long_desc <<-LONGDESC
      Fine-tunes a model using the specified base model and training data.

      BASE_MODEL: The name or path of the base model to fine-tune. Use 'list_models' to see available models.

      Options:
      --training-data: Path to the JSON file containing the training data. Defaults to the configured training data directory.
      --output-dir: Directory to save the fine-tuned model. Defaults to a directory in the configured workspace.
      --epochs: Number of training epochs (default: 3)
      --batch-size: Batch size for training (default: 8)
      --learning-rate: Learning rate for fine-tuning (default: 5e-5)
      --max-length: Maximum sequence length (default: 512)
      --evaluation-strategy: Evaluation strategy ('no', 'steps', 'epoch') (default: 'epoch')
      --eval-steps: Number of update steps between two evaluations if evaluation_strategy='steps'
      --force: Overwrite the output directory if it already exists
    LONGDESC
    option :training_data, type: :string, desc: "Path to the training data JSON file"
    option :output_dir, type: :string, desc: "Directory to save the fine-tuned model"
    option :epochs, type: :numeric, default: 3, desc: "Number of training epochs"
    option :batch_size, type: :numeric, default: 8, desc: "Batch size for training"
    option :learning_rate, type: :numeric, default: 5e-5, desc: "Learning rate for fine-tuning"
    option :max_length, type: :numeric, default: 512, desc: "Maximum sequence length"
    option :evaluation_strategy, type: :string, default: "epoch", desc: "Evaluation strategy ('no', 'steps', 'epoch')"
    option :eval_steps, type: :numeric, desc: "Number of update steps between two evaluations if evaluation_strategy='steps'"
    option :force, type: :boolean, default: false, desc: "Overwrite the output directory if it already exists"
    def fine_tune(base_model)
      config = RubyTuner.configuration

      # Set default training data path if not provided
      training_data = options[:training_data] || File.join(config.training_data_dir, "training_data.json")

      # Set default output directory if not provided
      output_dir = options[:output_dir] || File.join(config.fine_tuned_models_dir, Time.now.strftime("%Y%m%d%H%M%S"))

      # Check if output directory exists
      if File.directory?(output_dir) && !options[:force]
        raise Thor::Error, "Output directory already exists. Use --force to overwrite."
      end

      # Initialize FineTuningManager
      manager = RubyTuner::FineTuning::FineTuningManager.new

      # Prepare fine-tuning parameters
      fine_tuning_params = {
        base_model: base_model,
        training_data_path: training_data,
        output_dir: output_dir,
        epochs: options[:epochs],
        batch_size: options[:batch_size],
        learning_rate: options[:learning_rate],
        max_length: options[:max_length],
        evaluation_strategy: options[:evaluation_strategy],
        eval_steps: options[:eval_steps]
      }

      # Run fine-tuning
      say "Starting fine-tuning process...", :blue
      say "Using training data: #{training_data}", :blue
      say "Output will be saved to: #{output_dir}", :blue
      success = manager.run_fine_tuning(fine_tuning_params)

      if success
        say "Fine-tuning completed successfully.", :green
        say "Model saved to: #{output_dir}", :green
      else
        say "Fine-tuning failed to meet performance threshold.", :red
        say "Model was not saved.", :red
      end
    rescue RubyTuner::FineTuning::ConfigurationError, Thor::Error => e
      say e.message, :red
    end

    desc "generate CODE_PROMPT", "Generate code using a fine-tuned model"
    option :model, type: :string, required: true, desc: "Path to the fine-tuned model"
    def generate(code_prompt)
      manager = RubyTuner::FineTuning::FineTuningManager.new
      generated_code = manager.run_inference(options[:model], code_prompt)
      say "Generated Code:", :green
      say generated_code
    end
  end
end
