# frozen_string_literal: true

module RubyLLM
  module Providers
    class Anthropic
      # Batch processing methods for the Anthropic API integration
      module Batch
        def complete_batch(requests, **options)
          batch = create_batch(requests, **options)

          {
            batch_id: batch['id'],
            status: batch['processing_status'],
            results_url: batch['results_url'],
            created_at: batch['created_at'],
            expires_at: batch['expires_at'],
            request_counts: batch['request_counts']
          }
        end

        def get_batch_status(batch_id)
          batch_url = "#{api_base}/v1/messages/batches/#{batch_id}"

          response = @connection.get(batch_url) do |req|
            req.headers.merge!(headers)
          end

          unless response.success?
            error_message = parse_error(response)
            raise RubyLLM::Error, "Batch status check failed: #{error_message}"
          end

          JSON.parse(response.body)
        end

        def get_batch_results(batch_id)
          results_url = "#{api_base}/v1/messages/batches/#{batch_id}/results"

          response = @connection.get(results_url) do |req|
            req.headers.merge!(headers)
          end

          unless response.success?
            error_message = parse_error(response)
            raise RubyLLM::Error, "Batch results retrieval failed: #{error_message}"
          end

          JSON.parse(response.body)
        end

        private

        def create_batch(requests, **options)
          tools = options[:tools]
          temperature = options[:temperature]
          model = options[:model]
          params = options[:params]
          headers = options[:headers]
          schema = options[:schema]
          batch_url = "#{api_base}/v1/messages/batches"

          validate_batch_size(requests)

          custom_ids = Set.new
          formatted_requests = requests.map do |request|
            custom_id = request[:custom_id] || SecureRandom.uuid

            custom_id = "#{custom_id}_#{SecureRandom.hex(4)}" if custom_ids.include?(custom_id)
            custom_ids.add(custom_id)

            request_params = build_request_params(
              request,
              model: model,
              temperature: temperature,
              params: params,
              tools: tools,
              schema: schema
            )

            {
              custom_id: custom_id,
              params: request_params
            }
          end

          payload = {
            requests: formatted_requests
          }

          validate_payload_size(payload)

          response = @connection.post(batch_url) do |req|
            req.headers.merge!(headers)
            req.body = payload.to_json
          end

          unless response.success?
            error_message = parse_error(response)
            raise RubyLLM::Error, "Batch creation failed: #{error_message}"
          end

          JSON.parse(response.body)
        end

        def build_request_params(request, **options)
          model = options[:model]
          temperature = options[:temperature]
          params = options[:params]
          tools = options[:tools]
          schema = options[:schema]
          request_params = {
            model: model.id,
            max_tokens: params[:max_tokens] || 4096,
            temperature: temperature,
            messages: [
              {
                role: 'user',
                content: request[:message]
              }
            ]
          }

          request_params[:tools] = format_tools_for_batch(tools) if tools.any?

          request_params[:response_format] = { type: 'json_schema', json_schema: schema } if schema

          request_params
        end

        def validate_batch_size(requests)
          return unless requests.length > 10_000

          raise ArgumentError, "Batch size cannot exceed 10,000 requests (got #{requests.length})"
        end

        def validate_payload_size(payload)
          payload_size = payload.to_json.bytesize
          return unless payload_size > 256 * 1024 * 1024

          raise ArgumentError, "Batch payload size cannot exceed 256MB (got #{payload_size} bytes)"
        end

        def format_tools_for_batch(tools)
          tools.values.map { |t| Tools.function_for(t) }
        end
      end
    end
  end
end
