# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  module JsonRPC
    class RequestTest < ActiveSupport::TestCase
      test "Request.parse parses valid JSON-RPC request" do
        json = {
          jsonrpc: "2.0",
          method: "test_method",
          params: { foo: "bar" },
          id: 1,
        }.to_json

        request = Request.parse(json)
        assert_equal "2.0", request.version
        assert_equal "test_method", request.method
        assert_equal({ "foo" => "bar" }, request.params)
        assert_equal 1, request.id
      end

      test "Request.parse raises ParseError for invalid JSON" do
        assert_raises(ParseError) do
          Request.parse("invalid json")
        end
      end

      test "Request#initialize sets attributes" do
        request = Request.new(
          version: "2.0",
          method: "test_method",
          params: { "foo" => "bar" },
          id: 1,
        )

        assert_equal "2.0", request.version
        assert_equal "test_method", request.method
        assert_equal({ "foo" => "bar" }, request.params)
        assert_equal 1, request.id
      end

      test "Request#notification? returns true when id is nil" do
        request = Request.new(
          version: "2.0",
          method: "test_method",
        )
        assert request.notification?
      end

      test "Request#notification? returns false when id is present" do
        request = Request.new(
          version: "2.0",
          method: "test_method",
          id: 1,
        )
        refute request.notification?
      end

      test "Request#valid? returns true for valid request" do
        request = Request.new(
          version: "2.0",
          method: "test_method",
        )
        assert request.valid?
      end

      test "Request#valid? returns false for invalid version" do
        request = Request.new(
          version: "1.0",
          method: "test_method",
        )
        refute request.valid?
      end

      test "Request#validate! raises InvalidRequestError for invalid version" do
        assert_raises(InvalidRequestError) do
          Request.new(
            version: "1.0",
            method: "test_method",
          ).validate!
        end
      end

      test "Request#validate! raises InvalidRequestError for rpc prefixed method" do
        assert_raises(InvalidRequestError) do
          Request.new(
            version: "2.0",
            method: "rpc.test",
          ).validate!
        end
      end

      test "Request#method_not_found! raises MethodNotFoundError" do
        request = Request.new(
          version: "2.0",
          method: "test_method",
        )

        assert_raises(MethodNotFoundError) do
          request.method_not_found!
        end
      end
    end
  end
end
