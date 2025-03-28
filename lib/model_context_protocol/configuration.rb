# frozen_string_literal: true

module ModelContextProtocol
  class Configuration
    attr_writer :exception_reporter, :instrumentation_callback

    def initialize(exception_reporter: nil, instrumentation_callback: nil)
      @exception_reporter = exception_reporter
      @instrumentation_callback = instrumentation_callback
    end

    def exception_reporter
      @exception_reporter || default_exception_reporter
    end

    def exception_reporter?
      !@exception_reporter.nil?
    end

    def instrumentation_callback
      @instrumentation_callback || default_instrumentation_callback
    end

    def instrumentation_callback?
      !@instrumentation_callback.nil?
    end

    def merge(other)
      return self if other.nil?

      exception_reporter = if other.exception_reporter?
        other.exception_reporter
      else
        @exception_reporter
      end
      instrumentation_callback = if other.instrumentation_callback?
        other.instrumentation_callback
      else
        @instrumentation_callback
      end

      Configuration.new(
        exception_reporter:,
        instrumentation_callback:,
      )
    end

    private

    def default_exception_reporter
      @default_exception_reporter ||= ->(exception, context) {}
    end

    def default_instrumentation_callback
      @default_instrumentation_callback ||= ->(data) {}
    end
  end
end
