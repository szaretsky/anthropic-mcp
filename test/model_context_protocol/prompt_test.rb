# typed: strict
# frozen_string_literal: true

require "test_helper"

module ModelContextProtocol
  class PromptTest < ActiveSupport::TestCase
    test "#template validates arguments" do
      prompt = Prompt.new(
        name: "test_prompt",
        description: "Test prompt",
        arguments: [
          Prompt::Argument.new(name: "test_argument", description: "Test argument", required: true),
        ],
      )
      assert_raises(ArgumentError) do
        prompt.template({})
      end
    end

    test "#template returns a Result with description and messages when arguments are valid" do
      prompt = Prompt.new(
        name: "test_prompt",
        description: "Test prompt",
        arguments: [
          Prompt::Argument.new(name: "test_argument", description: "Test argument", required: true),
        ],
      ) do |_|
        Prompt::Result.new(
          description: "Hello, world!",
          messages: [
            Prompt::Message.new(role: "user", content: Content::Text.new("Hello, world!")),
            Prompt::Message.new(role: "assistant", content: Content::Text.new("Hello, friend!")),
          ],
        )
      end

      expected = {
        description: "Hello, world!",
        messages: [
          { role: "user", content: { text: "Hello, world!" } },
          { role: "assistant", content: { text: "Hello, friend!" } },
        ],
      }

      result = prompt.template({ "test_argument" => "Hello, friend!" })

      assert_equal expected, result.to_h
    end
  end
end
