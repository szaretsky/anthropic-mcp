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
        { content:, isError: is_error }.compact
      end
    end

    class Annotations
      attr_reader :title, :read_only_hint, :destructive_hint, :idempotent_hint, :open_world_hint

      def initialize(title: nil, read_only_hint: nil, destructive_hint: nil, idempotent_hint: nil, open_world_hint: nil)
        @title = title
        @read_only_hint = read_only_hint
        @destructive_hint = destructive_hint
        @idempotent_hint = idempotent_hint
        @open_world_hint = open_world_hint
      end

      def to_h
        {
          title:,
          readOnlyHint: read_only_hint,
          destructiveHint: destructive_hint,
          idempotentHint: idempotent_hint,
          openWorldHint: open_world_hint,
        }.compact
      end
    end

    class << self
      NOT_SET = Object.new

      attr_reader :description_value
      attr_reader :input_schema_value
      attr_reader :annotations_value

      def call(*args, server_context:)
        raise NotImplementedError, "Subclasses must implement call"
      end

      def to_h
        result = {
          name: name_value,
          description: description_value,
          inputSchema: input_schema_value,
        }
        result[:annotations] = annotations_value.to_h if annotations_value
        result
      end

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@name_value, nil)
        subclass.instance_variable_set(:@description_value, nil)
        subclass.instance_variable_set(:@input_schema_value, nil)
        subclass.instance_variable_set(:@annotations_value, nil)
      end

      def tool_name(value = NOT_SET)
        if value == NOT_SET
          name_value
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

      def input_schema(value = NOT_SET)
        if value == NOT_SET
          @input_schema_value
        else
          @input_schema_value = value
        end
      end

      def annotations(hash = NOT_SET)
        if hash == NOT_SET
          @annotations_value
        else
          @annotations_value = Annotations.new(**hash)
        end
      end

      def define(name: nil, description: nil, input_schema: nil, annotations: nil, &block)
        Class.new(self) do
          tool_name name
          description description
          input_schema input_schema
          self.annotations(annotations) if annotations
          define_singleton_method(:call) do |*args, server_context:|
            instance_exec(*args, server_context:, &block)
          end
        end
      end
    end
  end
end
