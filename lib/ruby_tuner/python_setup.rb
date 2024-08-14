# frozen_string_literal: true

require "open-uri"
require "json"
require "fileutils"
require "pycall"

module RubyTuner
  module PythonSetup
    class PythonNotInstalledError < RubyTuner::Error; end

    class << self
      def configure_environment
        if python_environment_valid?
          use_existing_python
        else
          setup_python_environment
        end
        set_environment_variables
        RubyTuner.configuration.python_executable = python_executable
        install_required_packages
        PyCall.init(python_executable)
      rescue PyCall::PythonNotFound => e
        RubyTuner.logger.error("An error occurred while setting up the Python environment: #{e.message}")
        RubyTuner.logger.info("Please ensure you have a valid Python 3.x installation with shared libraries.")
        RubyTuner.logger.info("You can try running 'ruby_tuner setup --force' to attempt a fresh installation.")
        raise PythonNotInstalledError.new(e)
      end

      def valid?
        # Assume the python env is valid if it has been configured.
        !RubyTuner.configuration.python_executable.to_s.strip.empty?
      end

      private

      def install_required_packages
        RubyTuner.logger.info "Installing required Python packages..."
        %w[transformers datasets accelerate scikit-learn].each do |package|
          RubyTuner.logger.info "Installing #{package}..."
          if system("#{python_executable} -m pip install #{package}")
            RubyTuner.logger.info("Successfully installed #{package}.")
          else
            RubyTuner.logger.error("Failed to install #{package}. Please install it manually.")
          end
        end
        # Exclusively install torch with MPS support on MacOS (if using it)
        RubyTuner.logger.info "Installing torch..."
        cmd = "#{python_executable} -m pip install torch"
        cmd << " --extra-index-url https://download.pytorch.org/whl/cpu" unless (RUBY_PLATFORM =~ /darwin/).nil?
        if system(cmd)
          RubyTuner.logger.info("Successfully installed torch.")
        else
          RubyTuner.logger.error("Failed to install torch. Please install it manually.")
        end
      end

      def python_environment_valid?
        %w[python3 python].each do |cmd|
          if system("which #{cmd} > /dev/null 2>&1") && python_has_shared_libraries?(cmd)
            @using_system_python = true
            @python_executable = cmd
            return true
          end
        end

        false
      end

      def python_has_shared_libraries?(path)
        `#{path} -c "import sysconfig; print(sysconfig.get_config_var('Py_ENABLE_SHARED'))"`.strip == "1"
      rescue
        false
      end

      def use_existing_python
        RubyTuner.logger.debug "Using an existing python installation: #{@python_executable}"
        # No need to install, just set the version
        version = `#{@python_executable} --version`.strip.split[1]
        cache_version(version)
      end

      def setup_python_environment
        RubyTuner.logger.debug "Installing python to: #{python_executable}"
        latest_version = get_latest_python_version
        cached_version = get_cached_version

        if latest_version != cached_version
          install_python(latest_version)
          cache_version(latest_version)
        end
      end

      def get_latest_python_version
        json = URI.open("https://www.python.org/api/v2/downloads/release/?is_published=true").read
        data = JSON.parse(json)
        latest_version = data.find do |d|
          d["name"].include?("3.12.4")
          #d["is_latest"] &&
          #  d["show_on_download_page"] &&
          #  d["version"] > 2 &&
          #  !d["pre_release"]
        end

        if latest_version
          RubyTuner.logger.debug "Identified latest python version: #{latest_version["name"]}"
          latest_version["name"].split(" ")[-1]
        else
          raise "No suitable Python version found"
        end
      end

      def get_cached_version
        File.exist?(version_file) ? File.read(version_file).strip : nil
      end

      def install_python(version)
        RubyTuner.logger.info "Installing python #{version} to: #{install_dir}..."
        url = "https://www.python.org/ftp/python/#{version}/Python-#{version}.tgz"
        filename = File.basename(url)

        FileUtils.mkdir_p(install_dir)
        Dir.chdir(install_dir) do
          system("curl -O #{url}")
          system("tar xzf #{filename}")
          Dir.chdir("Python-#{version}") do
            system("./configure --enable-shared --prefix=#{install_dir}")
            system("make")
            system("make install")
          end
        end
      end

      def cache_version(version)
        File.write(version_file, version)
      end

      def set_environment_variables
        ENV["PYTHON"] = python_executable
        # Only set LD_LIBRARY_PATH if we're using our installed Python
        ENV["LD_LIBRARY_PATH"] = File.join(install_dir, "lib") if !@using_system_python
      end

      def workspace_dir
        RubyTuner.configuration.workspace_dir
      end

      def install_dir
        @install_dir ||= File.join(workspace_dir, "bin", "python")
      end

      def version_file
        @version_file ||= File.join(install_dir, "version.txt")
      end

      def python_executable
        @python_executable ||= File.join(install_dir, "bin", "python3")
      end
    end
  end
end
