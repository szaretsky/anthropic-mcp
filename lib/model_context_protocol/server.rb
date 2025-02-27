# frozen_string_literal: true

module ModelContextProtocol
  class Server
    PROTOCOL_VERSION = "2024-11-05"

    attr_accessor :name, :tools, :prompts

    def initialize(name: "model_context_protocol", tools: [], prompts: [])
      @name = name
      @tools = tools.to_h { |t| [t.name, t] }
      @prompts = prompts.to_h { |p| [p.name, p] }
    end

    def handle(request)
      response = begin
        parsed_request = JsonRPC::Request.parse(request)
        parsed_request.validate!

        if parsed_request.notification?
          handle_notification(parsed_request)
        else
          call_method(parsed_request)
        end
      rescue JsonRPC::Error => e
        JsonRPC::Response.new(id: parsed_request&.id, error: e)
      end

      response
    end

    private

    def handle_notification(request)
      nil
    end

    def call_method(request)
      case request.method
      when "initialize"
        JsonRPC::Response.new(id: request.id, result: {
          protocolVersion: PROTOCOL_VERSION,
          capabilities: capabilities,
          serverInfo: server_info,
        })
      when "ping"
        JsonRPC::Response.new(id: request.id, result: "pong")
      when "tools/list"
        list_tools(request)
      when "tools/call"
        call_tool(request)
      when "prompts/list"
        list_prompts(request)
      when "prompts/get"
        get_prompt(request)
      else
        raise JsonRPC::MethodNotFoundError.new(message: "Method not found #{request.method}")
      end
    end

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

      JsonRPC::Response.new(id: request.id, result: result.to_h)
    end

    def list_tools(request)
      JsonRPC::Response.new(id: request.id, result: { tools: @tools.map { |_, tool| tool.to_h } })
    end

    def list_prompts(request)
      JsonRPC::Response.new(id: request.id, result: { prompts: @prompts.map { |_, prompt| prompt.to_h } })
    end

    def get_prompt(request)
      prompt_name = request.params&.dig("name")
      prompt = @prompts[prompt_name]
      raise JsonRPC::MethodNotFoundError.new(message: "Prompt not found #{prompt_name}") unless prompt

      begin
        result = prompt.template(request.params&.dig("arguments") || {})
      rescue ArgumentError => e
        raise JsonRPC::InvalidParamsError.new(message: e.message)
      end

      JsonRPC::Response.new(id: request.id, result: result.to_h)
    end
  end
end
