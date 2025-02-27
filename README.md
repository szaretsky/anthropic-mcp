# Model Context Protocol

A Ruby gem implementing Model Context Protocol + JSON RPC 2.0 spec

## Overview

Model Context Protocol provides a standardized way to interact with language models through a JSON RPC 2.0 interface.

It handles request/response formatting, error handling, and tool integrations in a type-safe manner using Sorbet.

See https://spec.modelcontextprotocol.io/specification/

This implementation breaks from the transport examples in the spec as it implements a POST-based JSON RPC call rather
than a stateful SSE transport.

## MCP Server

The `ModelContextProtocol::Server` class is the core component that handles JSON-RPC requests and responses.
It implements the Model Context Protocol specification, handling model context requests and responses.

### Key Features

- Implements JSON-RPC 2.0 message handling
- Supports protocol initialization and capability negotiation
- Manages tool registration and invocation
- Provides type-safe request/response handling using Sorbet

### Supported Methods

- `initialize` - Initializes the protocol and returns server capabilities
- `ping` - Simple health check that returns "pong"
- `tools/list` - Lists all registered tools and their schemas
- `tools/call` - Invokes a specific tool with provided arguments
- `prompts/list` - Lists all registered prompts and their schemas
- `prompts/get` - Retrieves a specific prompt by name

### Usage

Implement an `ApplicationController` which calls the `Server#handle` method, eg

```ruby
module ModelContextProtocol
  class ApplicationController < ActionController::Base

    sig { void }
    def index
      server = ModelContextProtocol::Server.new(
        name: "my_server",
        tools: [someTool, anotherTool],
        prompts: [myPrompt]
      )
      render(json: server.handle(request.body.read).to_h)
    end
  end
end
```

## Tools

MCP spec includes [Tools](https://modelcontextprotocol.io/docs/concepts/tools) which provide functionality to LLM apps.

This gem provides a `ModelContextProtocol::Tool` class that can be instantiated to create tools.

Tools can be passed into the `ModelContextProtocol::Server` constructor to register them with the server.

### Example Tool Implementation

The `Tool` class allows creating tools that can be used within the model context.
To create a tool, instantiate the class with the required parameters and an optional block:

```ruby
tool = ModelContextProtocol::Tool.new(name: "my_tool", description: "This tool performs specific functionality...") do |args|
  # Implement the tool's functionality here
  result = process_something(args["parameter_name"])
  ModelContextProtocol::Tool::Response.new([{ type: "text", text: result }], false )
end
```

## Prompts

MCP spec includes
[Prompts](https://modelcontextprotocol.io/docs/concepts/prompts), `Prompts` enable servers to define reusable prompt
templates and workflows that clients can easily surface to users and LLMs

The `Prompt` class allows creating prompts that can be used within the model context.

To create a prompt, instantiate the class with the required parameters and an optional block:

```ruby
prompt = ModelContextProtocol::Prompt.new(name: "my_prompt", description: "This prompt performs specific functionality...") do |args|
  # Implement the prompt's functionality here
  result = template_something(args["parameter_name"])
  ModelContextProtocol::Prompt::Response.new([{ type: "text", text: result }], false )
end
```




## Releases

TODO
