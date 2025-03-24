# frozen_string_literal: true

module ModelContextProtocol
  module Instrumentation
    def instrument_call(method, &block)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @instrumentation_data = {}
      add_instrumentation_data(method:)

      result = yield block

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      add_instrumentation_data(duration: end_time - start_time)

      ModelContextProtocol.configuration.instrumentation_callback.call(@instrumentation_data)

      result
    end

    def add_instrumentation_data(**kwargs)
      @instrumentation_data.merge!(kwargs)
    end
  end
end
