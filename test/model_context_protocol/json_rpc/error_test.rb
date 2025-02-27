# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  module JsonRPC
    class ErrorTest < ActiveSupport::TestCase
      test "Error#initialize sets attributes" do
        code = -32700
        message = "Test error"
        data = { foo: "bar" }
        error = Error.new(code: code, message: message, data: data)

        assert_equal code, error.code
        assert_equal message, error.message
        assert_equal data, error.data
      end

      test "Error#to_h returns hash representation" do
        error = Error.new(code: -32700, message: "Test error", data: { foo: "bar" })
        expected = {
          code: -32700,
          message: "Test error",
          data: { foo: "bar" },
        }
        assert_equal expected, error.to_h
      end

      test "Error#to_h excludes nil data" do
        error = Error.new(code: -32700, message: "Test error", data: nil)
        expected = {
          code: -32700,
          message: "Test error",
        }
        assert_equal expected, error.to_h
      end

      test "InvalidRequestError sets correct code" do
        error = InvalidRequestError.new(message: "Invalid request")
        assert_equal Error::INVALID_REQUEST_CODE, error.code
        assert_equal "Invalid request", error.message
      end

      test "ParseError sets correct code" do
        error = ParseError.new(message: "Parse error")
        assert_equal Error::PARSE_ERROR_CODE, error.code
        assert_equal "Parse error", error.message
      end

      test "MethodNotFoundError sets correct code" do
        error = MethodNotFoundError.new(message: "Method not found")
        assert_equal Error::METHOD_NOT_FOUND_CODE, error.code
        assert_equal "Method not found", error.message
      end

      test "InvalidParamsError sets correct code" do
        error = InvalidParamsError.new(message: "Invalid params")
        assert_equal Error::INVALID_PARAMS_CODE, error.code
        assert_equal "Invalid params", error.message
      end
    end
  end
end
