# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  class ServerTest < ActiveSupport::TestCase
    setup do
      @tool = Tool.new(name: "test_tool", description: "Test tool", input_schema: {})

      @prompt = Prompt.define(
        name: "test_prompt",
        description: "Test prompt",
        arguments: [
          Prompt::Argument.new(name: "test_argument", description: "Test argument", required: true),
        ],
      ) do |_|
        Prompt::Result.new(
          description: "Hello, world!",
          messages: [
            Prompt::Message.new(role: "user", content: Content::Text.new("Hello, world!")),
          ],
        )
      end

      @resource = Resource.new(
        uri: "test_resource",
        name: "Test resource",
        description: "Test resource",
        mime_type: "text/plain",
        contents: [Content::Text.new("Hello, world!")],
      )

      @server_name = "test_server"
      @server = Server.new(name: @server_name, tools: [@tool], prompts: [@prompt], resources: [@resource])
    end

    test "#handle ping request returns pong" do
      request = {
        jsonrpc: "2.0",
        method: "ping",
        id: 1,
      }.to_json

      response = @server.handle(request)
      refute_nil response

      assert_equal "pong", response.result
      assert_equal 1, response.id
    end

    test "#handle initialize request returns protocol info, server info, and capabilities" do
      request = {
        jsonrpc: "2.0",
        method: "initialize",
        id: 1,
      }.to_json

      response = @server.handle(request)
      refute_nil response

      result = response.result

      assert_equal Server::PROTOCOL_VERSION, result[:protocolVersion]
      assert_kind_of Hash, result[:capabilities]
      assert_equal @server_name, result[:serverInfo][:name]
      assert_equal ModelContextProtocol::VERSION, result[:serverInfo][:version]
    end

    test "#handle returns nil for notification requests" do
      request = {
        jsonrpc: "2.0",
        method: "some_notification",
      }.to_json

      assert_nil @server.handle(request)
    end

    test "#handle returns error response for invalid requests" do
      response = @server.handle("invalid json")
      assert_instance_of JsonRPC::Response, response
      assert_instance_of(JsonRPC::ParseError, response.error)
    end

    test "#handle tools/list returns available tools" do
      request = {
        jsonrpc: "2.0",
        method: "tools/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_kind_of Array, response.result[:tools]
      assert_equal "test_tool", response.result[:tools][0][:name]
      assert_equal "Test tool", response.result[:tools][0][:description]
      assert_equal({}, response.result[:tools][0][:inputSchema])
    end

    test "#tools_list_handler sets the tools/list handler" do
      @server.tools_list_handler do
        [{ name: "hammer", description: "Hammer time!" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "tools/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal({ tools: [{ name: "hammer", description: "Hammer time!" }] }, response.result)
    end

    test "#handle tools/call executes tool and returns result" do
      tool_name = "test_tool"
      tool_args = { "arg" => "value" }
      tool_response = Tool::Response.new([{ "result" => "success" }])

      @tool.expects(:call).with(**tool_args).returns(tool_response)

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: tool_args,
        },
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal tool_response.to_h, response.result
    end

    test "#handle tools/call returns error if the tool raises an error" do
      @tool.expects(:call).raises(StandardError.new("Tool error"))

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "test_tool",
          arguments: {},
        },
        id: 1,
      }.to_json

      response = @server.handle(request)

      assert_instance_of(JsonRPC::InternalError, response.error)
      assert_equal "Tool error", response.error&.message
    end

    test "#handle tools/call returns error for unknown tool" do
      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "unknown_tool",
          arguments: {},
        },
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_instance_of(JsonRPC::Response, response)
      assert_instance_of(JsonRPC::MethodNotFoundError, response.error)
    end

    test "#tools_call_handler sets the tools/call handler" do
      @server.tools_call_handler do |request|
        tool_name = request.params&.dig("name")
        return Tool::Response.new("#{tool_name} called successfully").to_h
      end

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: { name: "my_tool", arguments: {} },
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal({ content: "my_tool called successfully", is_error: false }, response.result)
    end

    test "#handle prompts/list returns list of prompts" do
      request = {
        jsonrpc: "2.0",
        method: "prompts/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal({ prompts: [@prompt.to_h] }, response.result)
    end

    test "#prompts_list_handler sets the prompts/list handler" do
      @server.prompts_list_handler do
        [{ name: "foo_prompt", description: "Foo prompt" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "prompts/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal({ prompts: [{ name: "foo_prompt", description: "Foo prompt" }] }, response.result)
    end

    test "#handle prompts/get returns templated prompt" do
      request = {
        jsonrpc: "2.0",
        method: "prompts/get",
        id: 1,
        params: {
          name: "test_prompt",
          arguments: { "test_argument" => "Hello, friend!" },
        },
      }.to_json

      expected_result = {
        description: "Hello, world!",
        messages: [
          { role: "user", content: { text: "Hello, world!" } },
        ],
      }

      response = @server.handle(request)

      assert_equal(expected_result, response.result)
    end

    test "#handle prompts/get returns error if prompt is not found" do
      request = {
        jsonrpc: "2.0",
        method: "prompts/get",
        id: 1,
        params: {
          name: "unknown_prompt",
          arguments: {},
        },
      }.to_json

      response = @server.handle(request)
      assert_instance_of(JsonRPC::Response, response)
      assert_instance_of(JsonRPC::MethodNotFoundError, response.error)
    end

    test "#handle prompts/get returns error if prompt arguments are invalid" do
      request = {
        jsonrpc: "2.0",
        method: "prompts/get",
        id: 1,
        params: {
          name: "test_prompt",
          arguments: { "unknown_argument" => "Hello, friend!" },
        },
      }.to_json

      response = @server.handle(request)
      assert_instance_of(JsonRPC::Response, response)
      assert_instance_of(JsonRPC::InvalidParamsError, response.error)
      assert_equal "Missing required arguments: test_argument", response.error.message
    end

    test "#prompts_get_handler sets the prompts/get handler" do
      @server.prompts_get_handler do |request|
        prompt_name = request.params&.dig("name")
        return Prompt::Result.new(
          description: prompt_name,
          messages: [
            Prompt::Message.new(role: "user", content: Content::Text.new(request.params&.dig("arguments", "foo"))),
          ],
        ).to_h
      end

      request = {
        jsonrpc: "2.0",
        method: "prompts/get",
        id: 1,
        params: { name: "foo_bar_prompt", arguments: { "foo" => "bar" } },
      }.to_json

      response = @server.handle(request)
      assert_equal(
        { description: "foo_bar_prompt", messages: [{ role: "user", content: { text: "bar" } }] },
        response.result,
      )
    end

    test "#handle resources/list returns a list of resources" do
      request = {
        jsonrpc: "2.0",
        method: "resources/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal({ resources: [@resource.to_h] }, response.result)
    end

    test "#resources_list_handler sets the resources/list handler" do
      @server.resources_list_handler do
        [{ uri: "test_resource", name: "Test resource", description: "Test resource" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "resources/list",
        id: 1,
      }.to_json

      response = @server.handle(request)
      assert_equal(
        { resources: [{ uri: "test_resource", name: "Test resource", description: "Test resource" }] },
        response.result,
      )
    end

    test "#handle resources/read returns a resource" do
      request = {
        jsonrpc: "2.0",
        method: "resources/read",
        id: 1,
        params: {
          uri: @resource.uri,
        },
      }.to_json

      response = @server.handle(request)
      assert_equal(@resource.to_h, response.result)
    end

    test "#handle resources/read returns error if resource is not found" do
      request = {
        jsonrpc: "2.0",
        method: "resources/read",
        id: 1,
        params: {
          uri: "unknown_resource",
        },
      }.to_json

      response = @server.handle(request)
      assert_instance_of(JsonRPC::Response, response)
      assert_equal "Resource not found unknown_resource", response.error.message
    end

    test "#resources_read_handler sets the resources/read handler" do
      @server.resources_read_handler do |request|
        uri = request.params&.dig("uri")

        Resource.new(
          uri: uri,
          name: "Test resource",
          description: "Test resource",
          mime_type: "text/plain",
          contents: [Content::Text.new("Lorem ipsum dolor sit amet")],
        ).to_h
      end

      request = {
        jsonrpc: "2.0",
        method: "resources/read",
        id: 1,
        params: {
          uri: "test_resource",
        },
      }.to_json

      response = @server.handle(request)
      assert_equal(
        {
          uri: "test_resource",
          name: "Test resource",
          description: "Test resource",
          mimeType: "text/plain",
          contents: [{ text: "Lorem ipsum dolor sit amet" }],
        },
        response.result,
      )
    end

    test "#handle unknown method returns method not found error" do
      request = {
        jsonrpc: "2.0",
        id: 1,
        method: "unknown_method",
      }.to_json

      response = @server.handle(request)
      assert_instance_of(JsonRPC::Response, response)
      assert_instance_of(JsonRPC::MethodNotFoundError, response.error)
    end
  end
end
