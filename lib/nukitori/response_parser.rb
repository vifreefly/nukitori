# frozen_string_literal: true

module Nukitori
  # Parses LLM response content (handles both Hash and markdown-wrapped JSON)
  class ResponseParser
    # @param content [Hash, String] Response content from LLM
    # @return [Hash] Parsed response
    def self.parse(content)
      return content if content.is_a?(Hash)

      text = content.is_a?(String) ? content : content.to_s
      text = text.strip
      text = text.gsub(/\A```json\s*/, '').gsub(/\s*```\z/, '')
      text = text.gsub(/\A```\s*/, '').gsub(/\s*```\z/, '')
      JSON.parse(text)
    end
  end
end
