# typed: strict
# frozen_string_literal: true

module ModelContextProtocol
  class Resource
    attr_reader :uri, :name, :description, :mime_type, :contents

    def initialize(uri:, name:, description:, mime_type:, contents:)
      @uri = uri
      @name = name
      @description = description
      @mime_type = mime_type
      @contents = contents
    end

    def to_h
      {
        uri: @uri,
        name: @name,
        description: @description,
        mimeType: @mime_type,
        contents: @contents.map(&:to_h),
      }
    end
  end
end
