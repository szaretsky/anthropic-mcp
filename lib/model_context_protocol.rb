# typed: strict
# frozen_string_literal: true

require "model_context_protocol/server"
require "model_context_protocol/string_utils"
require "model_context_protocol/tool"
require "model_context_protocol/tool/input_schema"
require "model_context_protocol/tool/annotations"
require "model_context_protocol/tool/response"
require "model_context_protocol/content"
require "model_context_protocol/resource"
require "model_context_protocol/resource/contents"
require "model_context_protocol/resource/embedded"
require "model_context_protocol/resource_template"
require "model_context_protocol/prompt"
require "model_context_protocol/prompt/argument"
require "model_context_protocol/prompt/message"
require "model_context_protocol/prompt/result"
require "model_context_protocol/version"
require "model_context_protocol/configuration"
require "model_context_protocol/methods"

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
