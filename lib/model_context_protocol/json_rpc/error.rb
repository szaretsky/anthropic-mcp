# frozen_string_literal: true

module ModelContextProtocol
  module JsonRPC
    class Error < StandardError
      PARSE_ERROR_CODE     = -32700
      INVALID_REQUEST_CODE = -32600
      METHOD_NOT_FOUND_CODE = -32601
      INVALID_PARAMS_CODE  = -32602
      INTERNAL_ERROR_CODE  = -32603

      attr_reader :code, :message, :data

      def initialize(code:, message:, data: nil)
        super(message)
        @code = code
        @message = message
        @data = data
      end

      def to_h
        { code:, message:, data: }.compact
      end
    end

    class InvalidRequestError < Error
      def initialize(message:)
        super(code: INVALID_REQUEST_CODE, message: message)
      end
    end

    class ParseError < Error
      def initialize(message:)
        super(code: PARSE_ERROR_CODE, message: message)
      end
    end

    class MethodNotFoundError < Error
      def initialize(message:)
        super(code: METHOD_NOT_FOUND_CODE, message: message)
      end
    end

    class InvalidParamsError < Error
      def initialize(message:)
        super(code: INVALID_PARAMS_CODE, message: message)
      end
    end

    class InternalError < Error
      def initialize(message:)
        super(code: INTERNAL_ERROR_CODE, message: message)
      end
    end

    class InvalidResponse < StandardError; end
  end
end
