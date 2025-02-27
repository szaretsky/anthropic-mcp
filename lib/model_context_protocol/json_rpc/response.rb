# frozen_string_literal: true

module ModelContextProtocol
  module JsonRPC
    class Response
      attr_reader :version, :result, :error, :id

      def initialize(result: nil, error: nil, id: nil)
        @version = VERSION
        @result = result
        @error = error
        @id = id

        validate!
      end

      def to_h
        { id:, result:, jsonrpc: @version, error: @error&.to_h }.compact
      end

      private

      def validate!
        raise InvalidResponse, "Result and error cannot both be present" if @result && @error
        raise InvalidResponse, "Either result or error must be present" if @result.nil? && @error.nil?
      end
    end
  end
end
