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

    class << self
      attr_reader :description_value
      attr_reader :arguments_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@name_value, nil)
        subclass.instance_variable_set(:@description_value, nil)
        subclass.instance_variable_set(:@arguments_value, nil)
      end

      def prompt_name(value)
        @name_value = value
      end

      def name_value
        @name_value || StringUtils.handle_from_class_name(name)
      end

      def description(value)
        @description_value = value
      end

      def arguments(value)
        @arguments_value = value
      end

      def define(name: nil, description: nil, arguments: [], &block)
        new(name:, description:, arguments:).tap do |prompt|
          prompt.define_singleton_method(:template) do |args|
            instance_exec(args, &block)
          end
        end
      end
    end

    attr_reader :name, :description, :arguments

    def initialize(name: nil, description: nil, arguments: nil)
      @name = name || self.class.name_value
      @description = description || self.class.description_value
      @arguments = arguments || self.class.arguments_value
    end

    def template(args)
      raise NotImplementedError, "Prompt subclasses must implement template"
    end

    def validate_arguments!(args)
      missing = required_args - args.keys
      return if missing.empty?

      raise ArgumentError, "Missing required arguments: #{missing.join(", ")}"
    end

    def to_h
      { name:, description:, arguments: arguments.map(&:to_h) }.compact
    end

    private

    def required_args
      arguments.filter_map { |arg| arg.name if arg.required }
    end
  end
end
