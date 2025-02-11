# frozen_string_literal: true

module RubyTuner
  module Server
    class SGLang < Base
      def start
        cmd_parts = [
          "docker run",
          "--gpus all",
          "--shm-size 32g",
          "-v #{@options[:volume]}:/root/.cache/huggingface",
          "-p #{@options[:port] || 3000}:#{@options[:port] || 3000}",
          hugging_face_token,
          "--ipc=host",
          "lmsysorg/sglang:latest",
          "python3 -m sglang.launch_server",
          "--model-path #{@model_path}",
          "--host #{@options[:host] || '127.0.0.1'}",
          "--port #{@options[:port] || 3000}",
          configure_parallelism,
          configure_memory,
          configure_performance
        ].compact

        RubyTuner.logger.debug "Starting SGLang Server: #{cmd_parts.join(" ").gsub(/HF_TOKEN=[^\b]*\b/, "HF_TOKEN=****")}..."
        if @options[:privileged]
          exec("sudo #{cmd_parts.join(" ")}")
        else
          exec(cmd_parts.join(" "))
        end
      end

      private

      def configure_parallelism
        return "--device cpu" if @options[:force_cpu]

        gpu_count = RubyTuner.gpu_count
        return "--device cpu" if gpu_count == 0

        [
          "--device cuda",
          "--tp #{calculate_tp(gpu_count)}",
          "--dp #{calculate_dp(gpu_count)}",
          "--enable-dp-attention",
          "--base-gpu-id 0"
        ].join(" ")
      end

      def calculate_tp(gpu_count)
        # Use tensor parallelism for large models across multiple GPUs
        [gpu_count, 2].min
      end

      def calculate_dp(gpu_count)
        # Use remaining GPUs for data parallelism
        [gpu_count / calculate_tp(gpu_count), 1].max
      end

      def configure_memory
        [
          "--mem-fraction-static 0.9",
          "--chunked-prefill-size 4096",
          "--max-running-requests 32"
        ].join(" ")
      end

      def configure_performance
        [
          "--stream-interval 2",
          "--enable-metrics",
          "--enable-cache-report",
          get_gpu_features
        ].compact.join(" ")
      end

      def get_gpu_features
        return nil unless RubyTuner.cuda_available?

        features = []
        features << "--enable-torch-compile" if gpu_supports_compile?
        features << "--enable-mixed-chunk"
        features.join(" ")
      end

      def gpu_supports_compile?
        gpu_info = `nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null`.strip
        return false if gpu_info.empty?

        major, minor = gpu_info.split('.').map(&:to_i)
        major >= 7  # Ampere or newer GPUs
      rescue
        false
      end

      def hugging_face_token
        token = ENV['HUGGING_FACE_ACCESS_TOKEN']
        "--env HF_TOKEN=#{token}" if token
      end
    end
  end
end
