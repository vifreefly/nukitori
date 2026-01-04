# frozen_string_literal: true

require 'nokogiri'
require 'ruby_llm'
require 'ruby_llm/schema'
require 'json'

require_relative 'nukitori/version'
require_relative 'nukitori/response_parser'
require_relative 'nukitori/html_preprocessor'
require_relative 'nukitori/chat_factory'
require_relative 'nukitori/schema_generator'
require_relative 'nukitori/data_extractor'

module Nukitori
  # Path to bundled models.json with up-to-date model definitions
  MODELS_JSON = File.expand_path('nukitori/models.json', __dir__)
  class << self
    # Configure RubyLLM through Nukitori
    # Automatically uses bundled models.json with latest model definitions
    #
    # @example
    #   Nukitori.configure do |config|
    #     config.default_model = 'gpt-5.2'
    #     config.openai_api_key = ENV['OPENAI_API_KEY']
    #   end
    #
    def configure
      RubyLLM.configure do |config|
        # Use bundled models.json with up-to-date model definitions
        config.model_registry_file = MODELS_JSON
        yield config if block_given?
      end
    end

    # Main entry point - callable as Nukitori(html, 'schema.json') { schema }
    #
    # @param html [String, Nokogiri::HTML::Document] HTML content or Nokogiri doc
    # @param schema_path [String, nil] Path to cache extraction schema (optional)
    # @param block [Proc] Schema definition block
    # @return [Hash] Extracted data
    #
    # @example With schema caching (recommended for scraping similar pages)
    #   data = Nukitori(html, 'repos_schema.json') do
    #     array :repos do
    #       object do
    #         string :name
    #         string :url
    #       end
    #     end
    #   end
    #
    # @example AI-only mode (no schema, calls LLM each time)
    #   data = Nukitori(html) do
    #     array :products do
    #       object do
    #         string :title
    #         number :price
    #       end
    #     end
    #   end
    #
    def call(html, schema_path = nil, &block)
      raise ArgumentError, "Block required for schema definition" unless block_given?

      if schema_path
        extract_with_schema(html, schema_path, &block)
      else
        extract_with_ai(html, &block)
      end
    end

    private

    # XPath-based extraction with reusable schema
    def extract_with_schema(html, schema_path, &block)
      doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html)

      xpath_schema = if File.exist?(schema_path)
        JSON.parse(File.read(schema_path))
      else
        generate_and_save_schema(doc, schema_path, &block)
      end

      extractor = DataExtractor.new(xpath_schema)
      extractor.extract(doc)
    end

    # AI-only extraction (no schema, LLM extracts directly)
    def extract_with_ai(html, &block)
      schema_class = Class.new(RubyLLM::Schema, &block)
      processed_html = HtmlPreprocessor.process(html)

      chat = ChatFactory.create
      chat.with_schema(schema_class)
      chat.with_instructions("You are a web scraping/web data extraction expert. Extract data from the provided HTML according to the provided JSON schema. Return output in JSON format only, without any explanations.")

      response = chat.ask(processed_html)
      ResponseParser.parse(response.content)
    end

    def generate_and_save_schema(doc, path, &block)
      generator = SchemaGenerator.new(&block)
      xpath_schema = generator.create_extraction_schema_for(doc)
      File.write(path, JSON.pretty_generate(xpath_schema))
      xpath_schema
    end
  end
end

# DSL method - allows Nukitori(html, 'schema.json') { ... } syntax
def Nukitori(html, schema_path = nil, &block)
  Nukitori.call(html, schema_path, &block)
end
