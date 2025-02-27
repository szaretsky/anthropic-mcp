# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  class ToolTest < ActiveSupport::TestCase
    test "#to_h returns a hash with name, description, and inputSchema" do
      tool = Tool.new(name: "mock_tool", description: "a mock tool for testing")
      assert_equal tool.to_h, { name: "mock_tool", description: "a mock tool for testing", inputSchema: nil }
    end

    test "#call invokes the tool block and returns the response" do
      tool = Tool.new(name: "mock_tool", description: "a mock tool for testing") do |_|
        Tool::Response.new([{ type: "text", content: "OK" }])
      end

      response = tool.call
      assert_equal response.content, [{ type: "text", content: "OK" }]
      assert_equal response.is_error, false
    end
  end
end
