# frozen_string_literal: true

module ModelContextProtocol
  class Server
    PROTOCOL_VERSION = "2024-11-05"

    attr_accessor :name, :tools, :prompts, :resources

    def initialize(name: "model_context_protocol", tools: [], prompts: [], resources: [])
      @name = name
      @tools = tools.to_h { |t| [t.name, t] }
      @prompts = prompts.to_h { |p| [p.name, p] }
      @resources = resources
      @resource_index = resources.index_by(&:uri)

      @handlers = {
        "resources/list" => method(:list_resources),
        "resources/read" => method(:read_resource),
        "tools/list" => method(:list_tools),
        "tools/call" => method(:call_tool),
        "prompts/list" => method(:list_prompts),
        "prompts/get" => method(:get_prompt),
        "initialize" => method(:init),
        "ping" => method(:ping),
      }
    end

    def handle(request)
      response = begin
        parsed_request = JsonRPC::Request.parse(request)
        parsed_request.validate!

        if parsed_request.notification?
          handle_notification(parsed_request)
        else
          handle_method(parsed_request)
        end
      rescue JsonRPC::Error => e
        JsonRPC::Response.new(id: parsed_request&.id, error: e)
      end

      response
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

    def capabilities
      @capabilities ||= {
        experimental: nil,
        logging: nil,
        prompts: nil,
        resources: nil,
        tools: {},
        model_config: nil,
      }.compact
    end

    def server_info
      @server_info ||= {
        name:,
        version: ModelContextProtocol::VERSION,
      }
    end

    def handle_notification(request)
      nil
    end

    def handle_method(request)
      request_handler = @handlers[request.method]
      raise JsonRPC::MethodNotFoundError.new(message: "Method not found #{request.method}") unless request_handler

      result = request_handler.call(request)
      wrapped_result = case request.method
      when "tools/list"
        { tools: result }
      when "prompts/list"
        { prompts: result }
      when "resources/list"
        { resources: result }
      else
        result
      end

      JsonRPC::Response.new(id: request.id, result: wrapped_result)
    end

    def init(request)
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: capabilities,
        serverInfo: server_info,
      }
    end

    def ping(request)
      "pong"
    end

    def call_tool(request)
      tool_name = request.params&.dig("name")
      tool = tools[tool_name]
      raise JsonRPC::MethodNotFoundError.new(message: "Tool not found #{tool_name}") unless tool

      tool_args = request.params&.dig("arguments")

      result = begin
        tool.call(**tool_args)
      rescue => e
        raise JsonRPC::InternalError.new(message: e.message)
      end

      result.to_h
    end

    def list_tools(request)
      @tools.map { |_, tool| tool.to_h }
    end

    def list_prompts(request)
      @prompts.map { |_, prompt| prompt.to_h }
    end

    def get_prompt(request)
      prompt_name = request.params&.dig("name")
      prompt = @prompts[prompt_name]
      raise JsonRPC::MethodNotFoundError.new(message: "Prompt not found #{prompt_name}") unless prompt

      begin
        prompt_args = request.params&.dig("arguments")
        prompt.validate_arguments!(prompt_args)

        result = prompt.template(prompt_args)
      rescue ArgumentError => e
        raise JsonRPC::InvalidParamsError.new(message: e.message)
      end

      result.to_h
    end

    def list_resources(request)
      @resources.map(&:to_h)
    end

    def read_resource(request)
      resource_uri = request.params&.dig("uri")

      resource = @resource_index[resource_uri]
      raise JsonRPC::MethodNotFoundError.new(message: "Resource not found #{resource_uri}") unless resource

      resource.to_h
    end
  end
end
