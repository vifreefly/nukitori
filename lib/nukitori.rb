# frozen_string_literal: true

require 'nokogiri'
require 'ruby_llm'
require 'ruby_llm/schema'
require 'json'

require_relative 'nukitori/version'
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
    # @param schema_path [String] Path to cache extraction schema (required)
    # @param block [Proc] Schema definition block
    # @return [Hash] Extracted data
    #
    # @example
    #   data = Nukitori(html, 'repos_schema.json') do
    #     array :repos do
    #       object do
    #         string :name
    #         string :url
    #       end
    #     end
    #   end
    #
    def call(html, schema_path, &block)
      raise ArgumentError, "Schema path required" unless schema_path.is_a?(String)
      raise ArgumentError, "Block required for schema definition" unless block_given?

      doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html)

      xpath_schema = if File.exist?(schema_path)
        JSON.parse(File.read(schema_path))
      else
        generate_and_save_schema(doc, schema_path, &block)
      end

      extractor = DataExtractor.new(xpath_schema)
      extractor.extract(doc)
    end

    private

    def generate_and_save_schema(doc, path, &block)
      generator = SchemaGenerator.new(&block)
      xpath_schema = generator.create_extraction_schema_for(doc)
      File.write(path, JSON.pretty_generate(xpath_schema))
      xpath_schema
    end
  end
end

# DSL method - allows Nukitori(html, 'schema.json') { ... } syntax
def Nukitori(html, schema_path, &block)
  Nukitori.call(html, schema_path, &block)
end
