# frozen_string_literal: true

module ModelContextProtocol
  class Configuration
    attr_accessor :exception_reporter
    attr_accessor :instrumentation_callback

    def initialize
      @exception_reporter = ->(exception, context) {} # Default no-op reporter
      @instrumentation_callback = ->(data) {} # Default no-op callback
    end
  end
end
