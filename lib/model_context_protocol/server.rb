# frozen_string_literal: true

require "json_rpc_handler"
require_relative "instrumentation"

module ModelContextProtocol
  class Server
    class RequestHandlerError < StandardError
      def initialize(message, request)
        super(message)
        @request = request
      end
    end

    PROTOCOL_VERSION = "2025-03-26"

    include Instrumentation

    attr_accessor :name, :tools, :prompts, :resources, :context, :configuration

    def initialize(name: "model_context_protocol", tools: [], prompts: [], resources: [], context: nil,
      configuration: nil)
      @name = name
      @tools = tools.to_h { |t| [t.name_value, t] }
      @prompts = prompts.to_h { |p| [p.name_value, p] }
      @resources = resources
      @resource_index = resources.index_by(&:uri)
      @context = context
      @configuration = ModelContextProtocol.configuration.merge(configuration)
      @handlers = {
        "resources/list" => method(:list_resources),
        "resources/read" => method(:read_resource),
        "tools/list" => method(:list_tools),
        "tools/call" => method(:call_tool),
        "prompts/list" => method(:list_prompts),
        "prompts/get" => method(:get_prompt),
        "initialize" => method(:init),
        "ping" => ->(_) { {} },
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
      @handlers["resources/list"] = block
    end

    def resources_read_handler(&block)
      @handlers["resources/read"] = block
    end

    def tools_list_handler(&block)
      @handlers["tools/list"] = block
    end

    def tools_call_handler(&block)
      @handlers["tools/call"] = block
    end

    def prompts_list_handler(&block)
      @handlers["prompts/list"] = block
    end

    def prompts_get_handler(&block)
      @handlers["prompts/get"] = block
    end

    private

    def handle_request(request, method)
      instrument_call(method) do
        case method
        when "tools/list"
          ->(params) { { tools: @handlers["tools/list"].call(params) } }
        when "prompts/list"
          ->(params) { { prompts: @handlers["prompts/list"].call(params) } }
        when "resources/list"
          ->(params) { { resources: @handlers["resources/list"].call(params) } }
        else
          @handlers[method]
        end
      rescue => e
        report_exception(e, { request: request })
        raise RequestHandlerError.new("Internal error handling #{request[:method]} request", request)
      end
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
      add_instrumentation_data(method: "initialize")
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: capabilities,
        serverInfo: server_info,
      }
    end

    def list_tools(request)
      add_instrumentation_data(method: "tools/list")
      @tools.map { |_, tool| tool.to_h }
    end

    def call_tool(request)
      add_instrumentation_data(method: "tools/call")
      tool_name = request[:name]
      tool = tools[tool_name]
      unless tool
        add_instrumentation_data(error: :tool_not_found)
        raise "Tool not found #{tool_name}"
      end

      add_instrumentation_data(tool_name:)

      begin
        result = tool.call(**request[:arguments], context:)
        result.to_h
      rescue => e
        report_exception(e, { tool_name: tool_name, arguments: request[:arguments] })
        add_instrumentation_data(error: :internal_error)
        raise RequestHandlerError.new("Internal error calling tool #{tool_name}", request)
      end
    end

    def list_prompts(request)
      add_instrumentation_data(method: "prompts/list")
      @prompts.map { |_, prompt| prompt.to_h }
    end

    def get_prompt(request)
      add_instrumentation_data(method: "prompts/get")
      prompt_name = request[:name]
      prompt = @prompts[prompt_name]
      unless prompt
        add_instrumentation_data(error: :prompt_not_found)
        raise "Prompt not found #{prompt_name}"
      end

      add_instrumentation_data(prompt_name:)

      prompt_args = request[:arguments]
      prompt.validate_arguments!(prompt_args)

      prompt.template(prompt_args, context:).to_h
    end

    def list_resources(request)
      add_instrumentation_data(method: "resources/list")

      @resources.map(&:to_h)
    end

    def read_resource(request)
      add_instrumentation_data(method: "resources/read")
      resource_uri = request[:uri]

      resource = @resource_index[resource_uri]
      unless resource
        add_instrumentation_data(error: :resource_not_found)
        raise "Resource not found #{resource_uri}"
      end

      add_instrumentation_data(resource_uri:)
      resource.to_h
    end

    def report_exception(exception, context = {})
      configuration.exception_reporter.call(exception, context)
    end
  end
end
