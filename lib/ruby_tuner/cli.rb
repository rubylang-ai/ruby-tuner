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

    desc "serve MODEL_PATH", "Run a HuggingFace text-generation-inference server via Docker"
    long_desc <<-LONGDESC
      Runs a HuggingFace text-generation-inference server using Docker.
      Learn more: https://huggingface.co/docs/text-generation-inference/index

      MODEL_PATH: Path to the model directory or Hugging Face model ID.

      Options:
      --port: Port to run the server on (default: 8080)
      --docker-image: Docker image to use (default: ghcr.io/huggingface/text-generation-inference:latest)
    LONGDESC
    option :volume, type: :string, required: false, desc: "Path to use for cached model data", default: RubyTuner.configuration.base_model_path
    option :docker_image, type: :string, default: "ghcr.io/huggingface/text-generation-inference:latest"
    option :port, type: :numeric, required: false, desc: "Port to serve on", default: 3000
    option :privileged, type: :boolean, required: false, desc: "Whether the docker command needs 'sudo'", default: false
    option :max_input_tokens, type: :numeric, default: 1024, desc: "Maximum number of input tokens"
    option :force_cpu, type: :boolean, default: false, desc: "Force CPU usage even if CUDA is available"
    def serve(model_path)
      raise Thor::Error, "Docker is not installed or not running. Please install Docker and ensure it's running." unless system((options[:privileged] ? "sudo " : "") + "docker info > /dev/null 2>&1")

      docker_image = options[:docker_image] || "ghcr.io/huggingface/text-generation-inference:latest"
      port = options[:port] || 3000
      max_input_tokens = options[:max_input_tokens] || 1024
      force_cpu = options[:force_cpu] || false
      # Determine if model_path is a local directory or a Hugging Face model ID
      volume = options[:volume] ||  RubyTuner.configuration.base_model_path
      token = ENV["HUGGING_FACE_ACCESS_TOKEN"]
      gpu_option = (RubyTuner.cuda_available? && !force_cpu) ? "--gpus all" : ""
      docker_command = options[:privileged] ? "sudo " : ""
      if token
        docker_command << "docker run --rm -it #{gpu_option} --shm-size 1g -e HF_TOKEN=#{token} -p #{port}:80 -v #{volume}:/data #{docker_image} --model-id #{model_path} --max-input-tokens #{max_input_tokens}"
      else
        docker_command << "docker run --rm -it #{gpu_option} --shm-size 1g -p #{port}:80 -v #{volume}:/data #{docker_image} --model-id #{model_path} --max-input-tokens #{max_input_tokens}"
      end

      say "Starting HuggingFace text-generation-inference server..."
      say "Model: #{model_path}"
      say "Port: #{port}"
      say "Docker image: #{docker_image}"
      say "Max input tokens: #{max_input_tokens}"
      say "Using GPU: #{(RubyTuner.cuda_available? && !force_cpu) ? 'Yes' : 'No'}"
      say "Using model cache dir: #{volume}"
      say "Running: #{docker_command}", :yellow
      say "This will serve the Chat API for #{model_path}: http://127.0.0.1:#{port}/v1/chat/completions"
      exec(docker_command)
    rescue => e
      raise Thor::Error, "Failed to start server: #{e.message}"
    end
  end
end
