# frozen_string_literal: true

require "json_rpc_handler"

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
        "ping" => ->(_) { {} },
      }
    end

    def handle(request)
      JsonRpcHandler.handle(request) do |method|
        handler = case method
        when "tools/list"
          ->(params) { { tools: @handlers["tools/list"].call(params) } }
        when "prompts/list"
          ->(params) { { prompts: @handlers["prompts/list"].call(params) } }
        when "resources/list"
          ->(params) { { resources: @handlers["resources/list"].call(params) } }
        else
          @handlers[method]
        end

        handler
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
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: capabilities,
        serverInfo: server_info,
      }
    end

    def list_tools(request)
      @tools.map { |_, tool| tool.to_h }
    end

    def call_tool(request)
      tool_name = request[:name]
      tool = tools[tool_name]
      raise "Tool not found #{tool_name}" unless tool

      result = tool.call(**request[:arguments])
      result.to_h
    end

    def list_prompts(request)
      @prompts.map { |_, prompt| prompt.to_h }
    end

    def get_prompt(request)
      prompt_name = request[:name]
      prompt = @prompts[prompt_name]

      raise "Prompt not found #{prompt_name}" unless prompt

      prompt_args = request[:arguments]
      prompt.validate_arguments!(prompt_args)

      result = prompt.template(prompt_args)

      result.to_h
    end

    def list_resources(request)
      @resources.map(&:to_h)
    end

    def read_resource(request)
      resource_uri = request[:uri]

      resource = @resource_index[resource_uri]
      raise "Resource not found #{resource_uri}" unless resource

      resource.to_h
    end
  end
end
