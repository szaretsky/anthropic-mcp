# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  class ToolTest < ActiveSupport::TestCase
    class TestTool < Tool
      tool_name "test_tool"
      description "a test tool for testing"
      input_schema [{ type: "text", name: "message" }]

      class << self
        def call(message)
          Tool::Response.new([{ type: "text", content: "OK" }])
        end
      end
    end

    test "#to_h returns a hash with name, description, and inputSchema" do
      tool = Tool.define(name: "mock_tool", description: "a mock tool for testing")
      assert_equal tool.to_h, { name: "mock_tool", description: "a mock tool for testing", inputSchema: nil }
    end

    test "#call invokes the tool block and returns the response" do
      tool = TestTool
      response = tool.call("test")
      assert_equal response.content, [{ type: "text", content: "OK" }]
      assert_equal response.is_error, false
    end

    test "allows declarative definition of tools as classes" do
      class MockTool < Tool
        tool_name "my_mock_tool"
        description "a mock tool for testing"
        input_schema [{ type: "text", name: "message" }]
      end

      tool = MockTool
      assert_equal tool.name_value, "my_mock_tool"
      assert_equal tool.description, "a mock tool for testing"
      assert_equal tool.input_schema, [{ type: "text", name: "message" }]
    end

    test "defaults to class name as tool name" do
      class DefaultNameTool < Tool
        description "a mock tool for testing"
        input_schema [{ type: "text", name: "message" }]
      end

      tool = DefaultNameTool

      assert_equal tool.name_value, "default_name_tool"
      assert_equal tool.description, "a mock tool for testing"
      assert_equal tool.input_schema, [{ type: "text", name: "message" }]
    end

    test ".define allows definition of simple tools with a block" do
      tool = Tool.define(name: "mock_tool", description: "a mock tool for testing") do |_|
        Tool::Response.new([{ type: "text", content: "OK" }])
      end

      assert_equal tool.name_value, "mock_tool"
      assert_equal tool.description, "a mock tool for testing"
      assert_equal tool.input_schema, nil
    end
  end
end
