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
      NOT_SET = Object.new

      attr_reader :description_value
      attr_reader :arguments_value

      def template(args, context:)
        raise NotImplementedError, "Subclasses must implement template"
      end

      def to_h
        { name: name_value, description: description_value, arguments: arguments_value.map(&:to_h) }.compact
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@name_value, nil)
        subclass.instance_variable_set(:@description_value, nil)
        subclass.instance_variable_set(:@arguments_value, nil)
      end

      def prompt_name(value = NOT_SET)
        if value == NOT_SET
          @name_value
        else
          @name_value = value
        end
      end

      def name_value
        @name_value || StringUtils.handle_from_class_name(name)
      end

      def description(value = NOT_SET)
        if value == NOT_SET
          @description_value
        else
          @description_value = value
        end
      end

      def arguments(value = NOT_SET)
        if value == NOT_SET
          @arguments_value
        else
          @arguments_value = value
        end
      end

      def define(name: nil, description: nil, arguments: [], &block)
        Class.new(self) do
          prompt_name name
          description description
          arguments arguments
          define_singleton_method(:template) do |args, context:|
            instance_exec(args, context:, &block)
          end
        end
      end

      def validate_arguments!(args)
        missing = required_args - args.keys
        return if missing.empty?

        raise ArgumentError, "Missing required arguments: #{missing.join(", ")}"
      end

      private

      def required_args
        arguments_value.filter_map { |arg| arg.name.to_sym if arg.required }
      end
    end
  end
end
