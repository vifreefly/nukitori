# frozen_string_literal: true

module Nukitori
  # Extracts data directly using LLM (no schema generation/caching)
  class LlmExtractor
    class << self
      # Extract data from HTML using LLM directly
      # @param html [String, Nokogiri::HTML::Document] HTML content
      # @param block [Proc] Schema definition block
      # @return [Hash] Extracted data
      def extract(html, &block)
        raise ArgumentError, "Block required for schema definition" unless block_given?

        schema_class = Class.new(RubyLLM::Schema, &block)
        processed_html = HtmlPreprocessor.process(html)

        chat = ChatFactory.create
        chat.with_schema(schema_class) if support_structured_output?(chat.model)
        chat.with_instructions(build_prompt(schema_class))

        response = chat.ask(processed_html)
        ResponseParser.parse(response.content)
      end

      private

      def support_structured_output?(model)
        model.capabilities.include?('structured_output') && !model.id.include?('deepseek')
      end

      def build_prompt(schema_class)
        schema = JSON.parse(schema_class.new.to_json)
        properties = schema.dig('schema', 'properties')

        <<~PROMPT
          You are a web data extraction expert.

          ## Task
          Extract data from the provided HTML according to the JSON schema.
          Return ONLY valid JSON, no other text.
          STRICTLY FOLLOW the requirements schema provided.

          ## Requirements Schema (what to extract)
          ```json
          #{properties.to_json}
          ```
        PROMPT
      end
    end
  end
end
