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
        prompts: [myPrompt],
        context: nil,
      )
      render(json: server.handle(request.body.read).to_h)
    end
  end
end
```

## Configuration

The gem can be configured using the `ModelContextProtocol.configure` block:

```ruby
ModelContextProtocol.configure do |config|
  config.exception_reporter = ->(exception, context) do
    # Your exception reporting logic here
    # For example with Bugsnag:
    Bugsnag.notify(exception) do |report|
      report.add_metadata(:model_context_protocol, context)
    end
  end

  config.instrumentation_callback = -> (data) { puts "Got instrumentation data #{data.inspect}" }
end
```

### Exception Reporting

The exception reporter receives two arguments:
- `exception`: The Ruby exception object that was raised
- `context`: A hash containing contextual information about where the error occurred

The context hash includes:
- For tool calls: `{ tool_name: "name", arguments: { ... } }`
- For general request handling: `{ request: { ... } }`

When an exception occurs:
1. The exception is reported via the configured reporter
2. For tool calls, a generic error response is returned to the client: `{ error: "Internal error occurred", is_error: true }`
3. For other requests, the exception is re-raised after reporting

If no exception reporter is configured, a default no-op reporter is used that silently ignores exceptions.

## Tools

MCP spec includes [Tools](https://modelcontextprotocol.io/docs/concepts/tools) which provide functionality to LLM apps.

This gem provides a `ModelContextProtocol::Tool` class that can be used to create tools in two ways:

1. As a class definition:

```ruby
class MyTool < ModelContextProtocol::Tool
  description "This tool performs specific functionality..."
  input_schema [{ type: "text", name: "message" }]

  def call(message, context:)
    Tool::Response.new([{ type: "text", content: "OK" }])
  end
end

tool = MyTool.new
```

2. By using the `ModelContextProtocol::Tool.define` method with a block:

```ruby
tool = ModelContextProtocol::Tool.define(name: "my_tool", description: "This tool performs specific functionality...") do |args, context|
  Tool::Response.new([{ type: "text", content: "OK" }])
end
```

The context parameter is the context passed into the server and can be used to pass per request information,
e.g. around authentication state.

## Prompts

MCP spec includes [Prompts](https://modelcontextprotocol.io/docs/concepts/prompts), which enable servers to define reusable prompt templates and workflows that clients can easily surface to users and LLMs.

The `ModelContextProtocol::Prompt` class provides two ways to create prompts:

1. As a class definition with metadata:

```ruby
class MyPrompt < ModelContextProtocol::Prompt
  prompt_name "my_prompt"  # Optional - defaults to underscored class name
  description "This prompt performs specific functionality..."
  arguments [
    Prompt::Argument.new(
      name: "message",
      description: "Input message",
      required: true
    )
  ]

  def template(args)
    Prompt::Result.new(
      description: "Response description",
      messages: [
        Prompt::Message.new(
          role: "user",
          content: Content::Text.new("User message")
        ),
        Prompt::Message.new(
          role: "assistant",
          content: Content::Text.new(args["message"])
        )
      ]
    )
  end
end
```

2. Using the `ModelContextProtocol::Prompt.define` method:

```ruby
prompt = ModelContextProtocol::Prompt.define(
  name: "my_prompt",
  description: "This prompt performs specific functionality...",
  arguments: [
    Prompt::Argument.new(
      name: "message",
      description: "Input message",
      required: true
    )
  ]
) do |args|
  Prompt::Result.new(
    description: "Response description",
    messages: [
      Prompt::Message.new(
        role: "user",
        content: Content::Text.new("User message")
      ),
      Prompt::Message.new(
        role: "assistant",
        content: Content::Text.new(args["message"])
      )
    ]
  )
end
```

### Key Components

- `Prompt::Argument` - Defines input parameters for the prompt template
- `Prompt::Message` - Represents a message in the conversation with a role and content
- `Prompt::Result` - The output of a prompt template containing description and messages
- `Content::Text` - Text content for messages

### Usage

Register prompts with the MCP server:

```ruby
server = ModelContextProtocol::Server.new(
  name: "my_server",
  prompts: [MyPrompt.new],
  context: nil,
)
```

The server will handle prompt listing and execution through the MCP protocol methods:

- `prompts/list` - Lists all registered prompts and their schemas
- `prompts/get` - Retrieves and executes a specific prompt with arguments

### Instrumentation

The server allows registering a callback to receive information about instrumentation.
To register a handler pass a proc/lambda to as `instrumentation_callback` into the server constructor.

```ruby
ModelContextProtocol.configure do |config|
  config.instrumentation_callback = -> (data) { puts "Got instrumentation data #{data.inspect}" }
end
```

The data contains the following keys:
`method`: the metod called, e.g. `ping`, `tools/list`, `tools/call` etc
`tool_name`: the name of the tool called
`prompt_name`: the name of the prompt called
`resource_uri`: the uri of the resource called
`error`: if looking up tools/prompts etc failed, e.g. `tool_not_found`
`duration`: the duration of the call in seconds

`tool_name`, `prompt_name` and `resource_uri` are only populated if a matching handler is registered.
This is to avoid potential issues with metric cardinality

## Releases

TODO
