# frozen_string_literal: true

require "test_helper"
require "json"

module ModelContextProtocol
  class ServerTest < ActiveSupport::TestCase
    include InstrumentationTestHelper
    setup do
      @tool = Tool.define(name: "test_tool", description: "Test tool", input_schema: {})

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
      ModelContextProtocol.configure do |config|
        config.instrumentation_callback = instrumentation_helper.callback
      end

      @server = Server.new(
        name: @server_name,
        tools: [@tool],
        prompts: [@prompt],
        resources: [@resource],
      )
    end

    # https://spec.modelcontextprotocol.io/specification/2024-11-05/basic/utilities/ping/#behavior-requirements
    test "#handle ping request returns empty response" do
      request = {
        jsonrpc: "2.0",
        method: "ping",
        id: "123",
      }

      response = @server.handle(request)
      assert_equal(
        {
          "jsonrpc": "2.0",
          "id": "123",
          "result": {},
        },
        response,
      )
      assert_instrumentation_data({ method: "ping" })
    end

    test "#handle_json ping request returns empty response" do
      request = JSON.generate({
        jsonrpc: "2.0",
        method: "ping",
        id: "123",
      })

      response = JSON.parse(@server.handle_json(request), symbolize_names: true)
      assert_equal(
        {
          "jsonrpc": "2.0",
          "id": "123",
          "result": {},
        },
        response,
      )
      assert_instrumentation_data({ method: "ping" })
    end

    test "#handle initialize request returns protocol info, server info, and capabilities" do
      request = {
        jsonrpc: "2.0",
        method: "initialize",
        id: 1,
      }

      response = @server.handle(request)
      refute_nil response

      expected_result = {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
          "protocolVersion": "2024-11-05",
          "capabilities": {
            "prompts": {},
            "resources": {},
            "tools": {},
          },
          "serverInfo": {
            "name": @server_name,
            "version": ModelContextProtocol::VERSION,
          },
        },
      }

      assert_equal expected_result, response
      assert_instrumentation_data({ method: "initialize" })
    end

    test "#handle returns nil for notification requests" do
      request = {
        jsonrpc: "2.0",
        method: "some_notification",
      }

      assert_nil @server.handle(request)
      assert_instrumentation_data({ method: "some_notification" })
    end

    test "#handle tools/list returns available tools" do
      request = {
        jsonrpc: "2.0",
        method: "tools/list",
        id: 1,
      }

      response = @server.handle(request)
      result = response[:result]
      assert_kind_of Array, result[:tools]
      assert_equal "test_tool", result[:tools][0][:name]
      assert_equal "Test tool", result[:tools][0][:description]
      assert_equal({}, result[:tools][0][:inputSchema])
      assert_instrumentation_data({ method: "tools/list" })
    end

    test "#handle_json tools/list returns available tools" do
      request = JSON.generate({
        jsonrpc: "2.0",
        method: "tools/list",
        id: 1,
      })

      response = JSON.parse(@server.handle_json(request), symbolize_names: true)
      result = response[:result]
      assert_kind_of Array, result[:tools]
      assert_equal "test_tool", result[:tools][0][:name]
      assert_equal "Test tool", result[:tools][0][:description]
    end

    test "#tools_list_handler sets the tools/list handler" do
      @server.tools_list_handler do
        [{ name: "hammer", description: "Hammer time!" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "tools/list",
        id: 1,
      }

      response = @server.handle(request)
      result = response[:result]
      assert_equal({ tools: [{ name: "hammer", description: "Hammer time!" }] }, result)
      assert_instrumentation_data({ method: "tools/list" })
    end

    test "#handle tools/call executes tool and returns result" do
      tool_name = "test_tool"
      tool_args = { "arg" => "value" }
      tool_response = Tool::Response.new([{ "result" => "success" }])

      @tool.expects(:call).with(**tool_args, context: @server.context).returns(tool_response)

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: tool_name,
          arguments: tool_args,
        },
        id: 1,
      }

      response = @server.handle(request)
      assert_equal tool_response.to_h, response[:result]
      assert_instrumentation_data({ method: "tools/call", tool_name: })
    end

    test "#handle_json tools/call executes tool and returns result" do
      tool_name = "test_tool"
      tool_args = { arg: "value" }
      tool_response = Tool::Response.new([{ result: "success" }])

      @tool.expects(:call).with(**tool_args, context: @server.context).returns(tool_response)

      request = JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        params: { name: tool_name, arguments: tool_args },
        id: 1,
      })

      response = JSON.parse(@server.handle_json(request), symbolize_names: true)
      assert_equal tool_response.to_h, response[:result]
      assert_instrumentation_data({ method: "tools/call", tool_name: })
    end

    test "#handle tools/call returns internal error and reports exception if the tool raises an error" do
      exception = StandardError.new("Tool error")
      @tool.expects(:call).raises(exception)

      ModelContextProtocol.configuration.exception_reporter.expects(:call).with(
        exception,
        {
          tool_name: "test_tool",
          arguments: {},
        },
      )

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "test_tool",
          arguments: {},
        },
        id: 1,
      }

      response = @server.handle(request)

      assert_equal "Internal error", response[:error][:message]
      assert_equal "Internal error calling tool test_tool", response[:error][:data]
      assert_instrumentation_data({ method: "tools/call", tool_name: "test_tool", error: :internal_error })
    end

    test "#handle_json returns internal error and reports exception if the tool raises an error" do
      exception = StandardError.new("Tool error")
      @tool.expects(:call).raises(exception)

      request = JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "test_tool",
          arguments: {},
        },
        id: 1,
      })

      response = JSON.parse(@server.handle_json(request), symbolize_names: true)
      assert_equal "Internal error", response[:error][:message]
      assert_equal "Internal error calling tool test_tool", response[:error][:data]
      assert_instrumentation_data({ method: "tools/call", tool_name: "test_tool", error: :internal_error })
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
      }

      response = @server.handle(request)
      assert_equal "Internal error", response[:error][:message]
      assert_equal "Tool not found unknown_tool", response[:error][:data]
      assert_instrumentation_data({ method: "tools/call", error: :tool_not_found })
    end

    test "#handle_json returns error for unknown tool" do
      request = JSON.generate({
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "unknown_tool",
          arguments: {},
        },
        id: 1,
      })

      response = JSON.parse(@server.handle_json(request), symbolize_names: true)
      assert_equal "Internal error", response[:error][:message]
    end

    test "#tools_call_handler sets the tools/call handler" do
      @server.tools_call_handler do |request|
        tool_name = request[:name]
        return Tool::Response.new("#{tool_name} called successfully").to_h
      end

      request = {
        jsonrpc: "2.0",
        method: "tools/call",
        params: { name: "my_tool", arguments: {} },
        id: 1,
      }

      response = @server.handle(request)
      assert_equal({ content: "my_tool called successfully", isError: false }, response[:result])
      assert_instrumentation_data({ method: "tools/call", tool_name: "my_tool" })
    end

    test "#handle prompts/list returns list of prompts" do
      request = {
        jsonrpc: "2.0",
        method: "prompts/list",
        id: 1,
      }

      response = @server.handle(request)
      assert_equal({ prompts: [@prompt.to_h] }, response[:result])
      assert_instrumentation_data({ method: "prompts/list" })
    end

    test "#prompts_list_handler sets the prompts/list handler" do
      @server.prompts_list_handler do
        [{ name: "foo_prompt", description: "Foo prompt" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "prompts/list",
        id: 1,
      }

      response = @server.handle(request)
      assert_equal({ prompts: [{ name: "foo_prompt", description: "Foo prompt" }] }, response[:result])
      assert_instrumentation_data({ method: "prompts/list" })
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
      }

      expected_result = {
        description: "Hello, world!",
        messages: [
          { role: "user", content: { text: "Hello, world!" } },
        ],
      }

      response = @server.handle(request)
      assert_equal(expected_result, response[:result])
      assert_instrumentation_data({ method: "prompts/get", prompt_name: "test_prompt" })
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
      }

      response = @server.handle(request)
      assert_equal("Prompt not found unknown_prompt", response[:error][:data])
      assert_instrumentation_data({ method: "prompts/get", error: :prompt_not_found })
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
      }

      response = @server.handle(request)
      assert_equal "Missing required arguments: test_argument", response[:error][:data]
      assert_instrumentation_data({ method: "prompts/get", prompt_name: "test_prompt" })
    end

    test "#prompts_get_handler sets the prompts/get handler" do
      @server.prompts_get_handler do |request|
        prompt_name = request[:name]
        return Prompt::Result.new(
          description: prompt_name,
          messages: [
            Prompt::Message.new(role: "user", content: Content::Text.new(request[:arguments][:foo])),
          ],
        ).to_h
      end

      request = {
        jsonrpc: "2.0",
        method: "prompts/get",
        id: 1,
        params: { name: "foo_bar_prompt", arguments: { "foo" => "bar" } },
      }

      response = @server.handle(request)
      assert_equal(
        { description: "foo_bar_prompt", messages: [{ role: "user", content: { text: "bar" } }] },
        response[:result],
      )
      assert_instrumentation_data({ method: "prompts/get", prompt_name: "foo_bar_prompt" })
    end

    test "#handle resources/list returns a list of resources" do
      request = {
        jsonrpc: "2.0",
        method: "resources/list",
        id: 1,
      }

      response = @server.handle(request)
      assert_equal({ resources: [@resource.to_h] }, response[:result])
      assert_instrumentation_data({ method: "resources/list" })
    end

    test "#resources_list_handler sets the resources/list handler" do
      @server.resources_list_handler do
        [{ uri: "test_resource", name: "Test resource", description: "Test resource" }]
      end

      request = {
        jsonrpc: "2.0",
        method: "resources/list",
        id: 1,
      }

      response = @server.handle(request)
      assert_equal(
        { resources: [{ uri: "test_resource", name: "Test resource", description: "Test resource" }] },
        response[:result],
      )
      assert_instrumentation_data({ method: "resources/list" })
    end

    test "#handle resources/read returns a resource" do
      request = {
        jsonrpc: "2.0",
        method: "resources/read",
        id: 1,
        params: {
          uri: @resource.uri,
        },
      }

      response = @server.handle(request)
      assert_equal(@resource.to_h, response[:result])
      assert_instrumentation_data({ method: "resources/read", resource_uri: @resource.uri })
    end

    test "#handle resources/read returns error if resource is not found" do
      request = {
        jsonrpc: "2.0",
        method: "resources/read",
        id: 1,
        params: {
          uri: "unknown_resource",
        },
      }

      response = @server.handle(request)
      assert_equal "Resource not found unknown_resource", response[:error][:data]
      assert_instrumentation_data({ method: "resources/read", error: :resource_not_found })
    end

    test "#resources_read_handler sets the resources/read handler" do
      @server.resources_read_handler do |request|
        uri = request[:uri]

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
      }

      response = @server.handle(request)
      assert_equal(
        {
          uri: "test_resource",
          name: "Test resource",
          description: "Test resource",
          mimeType: "text/plain",
          contents: [{ text: "Lorem ipsum dolor sit amet" }],
        },
        response[:result],
      )
      assert_instrumentation_data({ method: "resources/read" })
    end

    test "#handle unknown method returns method not found error" do
      request = {
        jsonrpc: "2.0",
        id: 1,
        method: "unknown_method",
      }

      response = @server.handle(request)

      assert_equal "Method not found", response[:error][:message]
      assert_equal "unknown_method", response[:error][:data]
      assert_instrumentation_data({ method: "unknown_method" })
    end
  end
end
