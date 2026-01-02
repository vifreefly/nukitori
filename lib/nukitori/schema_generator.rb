# frozen_string_literal: true

require 'json'

module Nukitori
  class SchemaGenerator
    attr_reader :model

    # @param model [String, nil] LLM model to use
    # @param block [Proc] Schema definition block
    #
    # @example
    #   generator = Nukitori::SchemaGenerator.new do
    #     array :repos do
    #       object do
    #         string :name
    #         string :url
    #       end
    #     end
    #   end
    #
    def initialize(model: nil, &block)
      @model = model
      @schema_block = block
    end

    # Create extraction schema for given HTML
    # @param html [String, Nokogiri::HTML::Document] HTML string or Nokogiri document
    # @return [Hash] Generated extraction schema
    #
    # @example
    #   extraction_schema = generator.create_extraction_schema_for(html)
    #
    def create_extraction_schema_for(html, &block)
      schema_block = block || @schema_block
      raise ArgumentError, "Schema definition required (pass block to initialize or this method)" unless schema_block

      doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html)
      requirements = build_requirements(&schema_block)
      processed_html = preprocess_doc(doc)
      normalized_requirements = normalize_requirements(requirements)
      prompt = build_prompt(normalized_requirements)

      chat = model ? RubyLLM.chat(model:) : RubyLLM.chat
      chat.with_instructions(prompt)

      response = chat.ask(processed_html)
      parse_response(response.content)
    end

    private

    def build_requirements(&block)
      schema_class = Class.new(RubyLLM::Schema)
      schema_class.class_eval(&block)
      schema_class.new.to_json
    end

    def parse_response(content)
      # Handle both raw JSON and markdown-wrapped JSON (```json ... ```)
      text = content.is_a?(String) ? content : content.text
      text = text.strip
      text = text.gsub(/\A```json\s*/, '').gsub(/\s*```\z/, '')
      text = text.gsub(/\A```\s*/, '').gsub(/\s*```\z/, '')
      JSON.parse(text)
    end

    def normalize_requirements(requirements)
      schema_json = JSON.parse(requirements)
      schema_json.dig('schema', 'properties')
    end

    def preprocess_doc(doc)
      # Clone to avoid modifying original
      doc = doc.dup

      # Remove non-content elements
      doc.css('script, style, noscript, svg, path, meta, link, head').remove

      # Remove style attributes
      doc.css('*').each { |node| node.remove_attribute('style') }

      # Keep only first 3 items of repeating elements
      truncate_repeating_elements(doc)

      # Collapse whitespace
      doc.to_html.gsub(/\s+/, ' ')
    end

    def truncate_repeating_elements(doc)
      selectors = [
        '[data-testid="results-list"] > *',
        '.search-results > *',
        '.list-items > *',
        'ul.results > li',
        '.product-list > *',
        'table tbody tr'
      ]

      selectors.each do |selector|
        items = doc.css(selector)
        next if items.length <= 3

        items[3..-1].each(&:remove)
      end

      doc
    end

    def build_prompt(requirements)
      <<~PROMPT
        You are an expert at analyzing HTML structure and generating XPath expressions.

        ## Task
        Analyze the provided HTML and generate an XPath schema that can extract data
        matching the requirements schema below. Return ONLY valid JSON, no other text.

        ## Requirements Schema (what to extract)
        ```json
        #{JSON.pretty_generate(requirements)}
        ```

        ## XPath Schema Format

        For each field in requirements, generate the corresponding XPath definition:

        1. **For primitive types** (string, integer, number, boolean):
           ```json
           {
             "field_name": {
               "xpath": "//div[@class='example']",
               "type": "string",
               "transform": "trim"
             }
           }
           ```

        2. **For arrays of objects**:
           ```json
           {
             "items_list": {
               "type": "array",
               "container_xpath": "//div[@class='item']",
               "items": {
                 "name": {"xpath": ".//h3", "type": "string", "transform": "trim"},
                 "price": {"xpath": ".//span[@class='price']", "type": "number", "transform": "to_int"}
               }
             }
           }
           ```

        3. **For arrays of strings**:
           ```json
           {
             "tags": {
               "type": "array",
               "container_xpath": ".//a[@class='tag']",
               "items": {
                 "xpath": ".",
                 "type": "string",
                 "transform": "trim"
               }
             }
           }
           ```

        ## XPath Rules

        - Use `container_xpath` to identify repeating elements for arrays
        - Use relative XPaths (starting with `.//` or `.`) for fields inside arrays
        - Do NOT use `/text()` - just select the element, we extract text automatically
        - Use `@attr` to extract attribute values (e.g., `@href`, `@src`), especially for schema attributes which ends at `link` or `url`
        - Prefer semantic attributes: `@data-testid`, `@role`, `@aria-label`
        - Prefer tag structure: `//article//h3/a` over class-based selectors
        - Available transforms: "trim", "to_int", "to_float", "strip_tags"

        ## CRITICAL: Avoid Page-Specific Values

        The XPath schema must work on ALL similar pages, not just this one. NEVER use:

        - **IDs with numbers/UUIDs**: `@id='product-price-19140'` or `@id='item-abc123'` — these are page-specific
        - **Dynamic function names**: `@x-data='initComponent_6956666703fbc()'` — these change per page load
        - **Hashed class names**: `Box-sc-62in7e-0`, `css-1a2b3c`, `styled-xyz123` — generated by CSS-in-JS
        - **Session/random tokens**: any attribute value that looks like a hash or random string

        Instead, use:
        - Class names that describe purpose: `@class='price'`, `@class='product-title'`
        - Structural patterns: `//div[@class='product']//span[contains(@class,'price')]`
        - Partial matches when needed: `contains(@id,'product-price')` instead of exact ID
        - Tag hierarchy: `//article//h3/a` — relies on structure, not dynamic values

        ## Output

        Return ONLY the JSON XPath schema. No explanations, no markdown code blocks.
      PROMPT
    end
  end
end
