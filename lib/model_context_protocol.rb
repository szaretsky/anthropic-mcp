# typed: strict
# frozen_string_literal: true

require_relative "model_context_protocol/server"
require_relative "model_context_protocol/string_utils"
require_relative "model_context_protocol/tool"
require_relative "model_context_protocol/tool/input_schema"
require_relative "model_context_protocol/tool/annotations"
require_relative "model_context_protocol/tool/response"
require_relative "model_context_protocol/content"
require_relative "model_context_protocol/resource"
require_relative "model_context_protocol/resource/contents"
require_relative "model_context_protocol/resource/embedded"
require_relative "model_context_protocol/resource_template"
require_relative "model_context_protocol/prompt"
require_relative "model_context_protocol/prompt/argument"
require_relative "model_context_protocol/prompt/message"
require_relative "model_context_protocol/prompt/result"
require_relative "model_context_protocol/version"
require_relative "model_context_protocol/configuration"
require_relative "model_context_protocol/methods"

module ModelContextProtocol
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

MCP = ModelContextProtocol
