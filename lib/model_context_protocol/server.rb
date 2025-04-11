# frozen_string_literal: true

require "json_rpc_handler"
require_relative "instrumentation"
require_relative "methods"

module ModelContextProtocol
  class Server
    class RequestHandlerError < StandardError
      attr_reader :error_type
      attr_reader :original_error

      def initialize(message, request, error_type: :internal_error, original_error: nil)
        super(message)
        @request = request
        @error_type = error_type
        @original_error = original_error
      end
    end

    include Instrumentation

    attr_accessor :name, :tools, :prompts, :resources, :context, :configuration

    def initialize(name: "model_context_protocol", tools: [], prompts: [], resources: [], context: nil,
      configuration: nil)
      @name = name
      @tools = tools.to_h { |t| [t.name_value, t] }
      @prompts = prompts.to_h { |p| [p.name_value, p] }
      @resources = resources
      @resource_index = index_resources_by_uri(resources)
      @context = context
      @configuration = ModelContextProtocol.configuration.merge(configuration)
      @handlers = {
        Methods::RESOURCES_LIST => method(:list_resources),
        Methods::RESOURCES_READ => method(:read_resource),
        Methods::TOOLS_LIST => method(:list_tools),
        Methods::TOOLS_CALL => method(:call_tool),
        Methods::PROMPTS_LIST => method(:list_prompts),
        Methods::PROMPTS_GET => method(:get_prompt),
        Methods::INITIALIZE => method(:init),
        Methods::PING => ->(_) { {} },
      }
    end

    def handle(request)
      JsonRpcHandler.handle(request) do |method|
        handle_request(request, method)
      end
    end

    def handle_json(request)
      JsonRpcHandler.handle_json(request) do |method|
        handle_request(request, method)
      end
    end

    def resources_list_handler(&block)
      @handlers[Methods::RESOURCES_LIST] = block
    end

    def resources_read_handler(&block)
      @handlers[Methods::RESOURCES_READ] = block
    end

    def tools_list_handler(&block)
      @handlers[Methods::TOOLS_LIST] = block
    end

    def tools_call_handler(&block)
      @handlers[Methods::TOOLS_CALL] = block
    end

    def prompts_list_handler(&block)
      @handlers[Methods::PROMPTS_LIST] = block
    end

    def prompts_get_handler(&block)
      @handlers[Methods::PROMPTS_GET] = block
    end

    private

    def handle_request(request, method)
      handler = @handlers[method]
      unless handler
        instrument_call("unsupported_method") {}
        return
      end

      ->(params) {
        instrument_call(method) do
          case method
          when Methods::TOOLS_LIST
            { tools: @handlers[Methods::TOOLS_LIST].call(params) }
          when Methods::PROMPTS_LIST
            { prompts: @handlers[Methods::PROMPTS_LIST].call(params) }
          when Methods::RESOURCES_LIST
            { resources: @handlers[Methods::RESOURCES_LIST].call(params) }
          else
            @handlers[method].call(params)
          end
        rescue => e
          report_exception(e, { request: request })
          if e.is_a?(RequestHandlerError)
            add_instrumentation_data(error: e.error_type)
            raise e
          end

          add_instrumentation_data(error: :internal_error)
          raise RequestHandlerError.new("Internal error handling #{method} request", request, original_error: e)
        end
      }
    end

    def capabilities
      @capabilities ||= {
        prompts: {},
        resources: {},
        tools: {},
      }
    end

    def server_info
      @server_info ||= {
        name:,
        version: ModelContextProtocol::VERSION,
      }
    end

    def init(request)
      add_instrumentation_data(method: Methods::INITIALIZE)
      {
        protocolVersion: configuration.protocol_version,
        capabilities: capabilities,
        serverInfo: server_info,
      }
    end

    def list_tools(request)
      add_instrumentation_data(method: Methods::TOOLS_LIST)
      @tools.map { |_, tool| tool.to_h }
    end

    def call_tool(request)
      add_instrumentation_data(method: Methods::TOOLS_CALL)
      tool_name = request[:name]
      tool = tools[tool_name]
      unless tool
        add_instrumentation_data(error: :tool_not_found)
        raise RequestHandlerError.new("Tool not found #{tool_name}", request, error_type: :tool_not_found)
      end

      add_instrumentation_data(tool_name:)

      begin
        tool.call(**request[:arguments], context:).to_h
      rescue => e
        raise RequestHandlerError.new("Internal error calling tool #{tool_name}", request, original_error: e)
      end
    end

    def list_prompts(request)
      add_instrumentation_data(method: Methods::PROMPTS_LIST)
      @prompts.map { |_, prompt| prompt.to_h }
    end

    def get_prompt(request)
      add_instrumentation_data(method: Methods::PROMPTS_GET)
      prompt_name = request[:name]
      prompt = @prompts[prompt_name]
      unless prompt
        add_instrumentation_data(error: :prompt_not_found)
        raise RequestHandlerError.new("Prompt not found #{prompt_name}", request, error_type: :prompt_not_found)
      end

      add_instrumentation_data(prompt_name:)

      prompt_args = request[:arguments]
      prompt.validate_arguments!(prompt_args)

      prompt.template(prompt_args, context:).to_h
    end

    def list_resources(request)
      add_instrumentation_data(method: Methods::RESOURCES_LIST)

      @resources.map(&:to_h)
    end

    def read_resource(request)
      add_instrumentation_data(method: Methods::RESOURCES_READ)
      resource_uri = request[:uri]

      resource = @resource_index[resource_uri]
      unless resource
        add_instrumentation_data(error: :resource_not_found)
        raise RequestHandlerError.new("Resource not found #{resource_uri}", request, error_type: :resource_not_found)
      end

      add_instrumentation_data(resource_uri:)
      resource.to_h
    end

    def report_exception(exception, context = {})
      configuration.exception_reporter.call(exception, context)
    end

    def index_resources_by_uri(resources)
      resources.each_with_object({}) do |resource, hash|
        hash[resource.uri] = resource
      end
    end
  end
end
