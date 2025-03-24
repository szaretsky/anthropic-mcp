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

    class << self
      attr_reader :description_value
      attr_reader :input_schema_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@name_value, nil)
        subclass.instance_variable_set(:@description_value, nil)
        subclass.instance_variable_set(:@input_schema_value, nil)
      end

      def tool_name(value)
        @name_value = value
      end

      def name_value
        @name_value || StringUtils.handle_from_class_name(name)
      end

      def description(value)
        @description_value = value
      end

      def input_schema(value)
        @input_schema_value = value
      end

      def define(name: nil, description: nil, input_schema: nil, &block)
        new(name:, description:, input_schema:).tap do |tool|
          tool.define_singleton_method(:call) do |*args, context:|
            instance_exec(*args, context:, &block)
          end
        end
      end
    end

    attr_reader :name, :description, :input_schema

    def initialize(name: nil, description: nil, input_schema: nil)
      @name = name || self.class.name_value
      @description = description || self.class.description_value
      @input_schema = input_schema || self.class.input_schema_value
    end

    def call(*args, context:)
      raise NotImplementedError, "Subclasses must implement call"
    end

    def to_h
      { name:, description:, inputSchema: input_schema }
    end
  end
end
