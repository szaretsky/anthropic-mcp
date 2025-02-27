# typed: strict
# frozen_string_literal: true

module ModelContextProtocol
  class Prompt
    class Argument
      attr_reader :name, :description, :required, :arguments

      def initialize(name:, description: nil, required: false)
        @name = name
        @description = description
        @required = required
        @arguments = arguments
      end

      def to_h
        { name:, description:, required: }.compact
      end
    end

    class Message
      attr_reader :role, :content

      def initialize(role:, content:)
        @role = role
        @content = content
      end

      def to_h
        { role:, content: content.to_h }.compact
      end
    end

    class Result
      attr_reader :description, :messages

      def initialize(description: nil, messages: [])
        @description = description
        @messages = messages
      end

      def to_h
        { description:, messages: messages.map(&:to_h) }.compact
      end
    end

    attr_reader :name, :description, :arguments

    def initialize(name:, description: nil, arguments: [], &block)
      @name = name
      @description = description
      @arguments = arguments
      @template_block = block
    end

    def template(args)
      validate_args!(args)
      result = @template_block.call(args)
      result
    end

    def to_h
      { name:, description:, arguments: arguments.map(&:to_h) }.compact
    end

    private

    def required_args
      arguments.filter_map { |arg| arg.name if arg.required }
    end

    def validate_args!(args)
      missing = required_args - args.keys
      return if missing.empty?

      raise ArgumentError, "Missing required arguments: #{missing.join(", ")}"
    end
  end
end
