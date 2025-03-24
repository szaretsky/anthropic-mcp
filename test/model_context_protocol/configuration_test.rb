# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  class ConfigurationTest < ActiveSupport::TestCase
    test "initializes with a default no-op exception reporter" do
      config = Configuration.new
      assert_respond_to config, :exception_reporter

      # The default reporter should be callable but do nothing
      exception = StandardError.new("test error")
      context = { test: "context" }

      # Should not raise any errors
      config.exception_reporter.call(exception, context)
    end

    test "allows setting a custom exception reporter" do
      config = Configuration.new
      reported_exception = nil
      reported_context = nil

      config.exception_reporter = ->(exception, context) do
        reported_exception = exception
        reported_context = context
      end

      test_exception = StandardError.new("test error")
      test_context = { foo: "bar" }

      config.exception_reporter.call(test_exception, test_context)

      assert_equal test_exception, reported_exception
      assert_equal test_context, reported_context
    end
  end
end
