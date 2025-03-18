# typed: strict
# frozen_string_literal: true

require "model_context_protocol/server"
require "model_context_protocol/string_utils"
require "model_context_protocol/tool"
require "model_context_protocol/content"
require "model_context_protocol/resource"
require "model_context_protocol/prompt"
require "model_context_protocol/version"

module ModelContextProtocol
  class Annotations
    attr_reader :audience, :priority

    def initialize(audience: nil, priority: nil)
      @audience = audience
      @priority = priority
    end
  end
end
