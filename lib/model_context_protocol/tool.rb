# frozen_string_literal: true

module ModelContextProtocol
  class Tool
    class Response
      attr_reader :content, :is_error

      def initialize(content, is_error = false)
        @content = content
        @is_error = is_error
      end

      def to_h
        { content:, is_error: }.compact
      end
    end

    attr_reader :name, :description, :input_schema

    def initialize(name:, description: nil, input_schema: nil, &block)
      @name = name
      @description = description
      @input_schema = input_schema
      @tool_block = block_given? ? block : -> { Response.new([{ type: "text", content: "OK" }]) }
    end

    def call(*args)
      @tool_block.call(*args)
    end

    def to_h
      { name:, description:, inputSchema: input_schema }
    end
  end
end
