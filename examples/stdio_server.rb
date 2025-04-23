#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "model_context_protocol"
require "model_context_protocol/transports/stdio"

# Create a simple tool
class ExampleTool < ModelContextProtocol::Tool
  description "A simple example tool that echoes back its arguments"
  input_schema type: "object",
    properties: {
      message: { type: "string" },
    },
    required: ["message"]

  class << self
    def call(message:, server_context:)
      ModelContextProtocol::Tool::Response.new([{
        type: "text",
        text: "Hello from example tool! Message: #{message}",
      }])
    end
  end
end

# Set up the server
server = ModelContextProtocol::Server.new(
  name: "example_server",
  tools: [ExampleTool],
)

# Create and start the transport
transport = ModelContextProtocol::Transports::StdioTransport.new(server)
transport.open
