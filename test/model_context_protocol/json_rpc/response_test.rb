# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  module JsonRPC
    class ResponseTest < ActiveSupport::TestCase
      test "Response#initialize sets attributes with result" do
        result = { foo: "bar" }
        id = 1
        response = Response.new(result: result, id: id)

        assert_equal "2.0", response.version
        assert_equal result, response.result
        assert_nil response.error
        assert_equal id, response.id
      end

      test "Response#initialize sets attributes with error" do
        error = Error.new(code: -32700, message: "Test error")
        id = 1
        response = Response.new(error: error, id: id)

        assert_equal "2.0", response.version
        assert_nil response.result
        assert_equal error, response.error
        assert_equal id, response.id
      end

      test "Response#to_h returns hash representation with result" do
        result = { foo: "bar" }
        id = 1
        response = Response.new(result: result, id: id)
        expected = {
          jsonrpc: "2.0",
          result: result,
          id: id,
        }
        assert_equal expected, response.to_h
      end

      test "Response#to_h returns hash representation with error" do
        error = Error.new(code: -32700, message: "Test error")
        id = 1
        response = Response.new(error: error, id: id)
        expected = {
          jsonrpc: "2.0",
          error: error.to_h,
          id: id,
        }
        assert_equal expected, response.to_h
      end

      test "Response#initialize raises InvalidResponse when both result and error present" do
        assert_raises(InvalidResponse) do
          Response.new(
            result: { foo: "bar" },
            error: Error.new(code: -32700, message: "Test error"),
          )
        end
      end

      test "Response#initialize raises InvalidResponse when neither result nor error present" do
        assert_raises(InvalidResponse) do
          Response.new
        end
      end
    end
  end
end
