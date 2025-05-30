# frozen_string_literal: true

require_relative "mcp/shared/version"
require_relative "mcp/shared/configuration"
require_relative "mcp/shared/instrumentation"
require_relative "mcp/shared/methods"
require_relative "mcp/shared/transport"
require_relative "mcp/shared/content"
require_relative "mcp/shared/string_utils"

require_relative "mcp/shared/resource"
require_relative "mcp/shared/resource/contents"
require_relative "mcp/shared/resource/embedded"
require_relative "mcp/shared/resource_template"

require_relative "mcp/shared/tool"
require_relative "mcp/shared/tool/input_schema"
require_relative "mcp/shared/tool/response"
require_relative "mcp/shared/tool/annotations"

require_relative "mcp/shared/prompt"
require_relative "mcp/shared/prompt/argument"
require_relative "mcp/shared/prompt/message"
require_relative "mcp/shared/prompt/result"

require_relative "mcp/server"
require_relative "mcp/server/transports/stdio"

module MCP
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end
  end

  class Annotations
    attr_reader :audience, :priority

    def initialize(audience: nil, priority: nil)
      @audience = audience
      @priority = priority
    end
  end
end
