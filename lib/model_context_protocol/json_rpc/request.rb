# frozen_string_literal: true

require "json"

module ModelContextProtocol
  module JsonRPC
    class Request
      class << self
        def parse(json)
          parsed = JSON.parse(json)
          from_h(parsed)
        rescue JSON::ParserError => e
          raise ParseError.new(message: e.message)
        end

        private

        def from_h(hash)
          new(version: hash["jsonrpc"], method: hash["method"], params: hash["params"], id: hash["id"])
        end
      end

      attr_reader :version, :method, :params, :id

      def initialize(version:, method:, params: nil, id: nil)
        @version = version
        @method = method
        @params = params
        @id = id
      end

      def notification?
        id.nil?
      end

      def valid?
        @version == JsonRPC::VERSION && !method.start_with?("rpc.")
      end

      def method_not_found!
        raise MethodNotFoundError.new(message: "Method not found #{method}")
      end

      def validate!
        raise InvalidRequestError.new(message: "Method cannot start with 'rpc.'") if method.start_with?("rpc.")
        raise InvalidRequestError.new(message: "Invalid JSON-RPC version") unless valid?
      end
    end
  end
end
