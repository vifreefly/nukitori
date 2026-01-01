# frozen_string_literal: true

require 'nokogiri'
require 'ruby_llm'
require 'ruby_llm/schema'
require 'json'

require_relative 'nukitori/version'
require_relative 'nukitori/schema_generator'
require_relative 'nukitori/extractor'

module Nukitori
  class << self
    # Configure RubyLLM through Nukitori
    #
    # @example
    #   Nukitori.configure do |config|
    #     config.default_model = 'gpt-5'
    #     config.openai_api_key = ENV['OPENAI_API_KEY']
    #   end
    #
    def configure(&block)
      RubyLLM.configure(&block)
    end

    # Main entry point - callable as Nukitori(html) { schema }
    #
    # @param html [String, Nokogiri::HTML::Document] HTML content or Nokogiri doc
    # @param schema_or_path [Hash, String, nil] Optional: XPath schema hash OR path to cache schema
    # @param block [Proc] RubyLLM::Schema definition block
    # @return [Hash] Extracted data
    #
    # @example Simple usage (generates schema each time)
    #   data = Nukitori(html) do
    #     array :repos do
    #       object do
    #         string :name
    #         string :url
    #       end
    #     end
    #   end
    #
    # @example With schema caching to file
    #   data = Nukitori(html, 'repos_schema.json') do
    #     array :repos do
    #       object do
    #         string :name
    #       end
    #     end
    #   end
    #
    # @example With direct xpath schema hash
    #   data = Nukitori(html, my_xpath_schema_hash)
    #
    def call(html, schema_or_path = nil, &block)
      doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html)

      xpath_schema = resolve_schema(doc, schema_or_path, &block)

      extractor = Extractor.new(xpath_schema)
      extractor.extract(doc)
    end

    private

    def resolve_schema(doc, schema_or_path, &block)
      case schema_or_path
      when Hash
        # Direct xpath schema provided
        schema_or_path
      when String
        # File path for caching
        if File.exist?(schema_or_path)
          JSON.parse(File.read(schema_or_path))
        elsif block_given?
          generate_and_save_schema(doc, schema_or_path, &block)
        else
          raise ArgumentError, "Schema file '#{schema_or_path}' not found and no block provided"
        end
      when nil
        # No caching, generate from block
        raise ArgumentError, "Block required when no schema provided" unless block_given?
        generate_schema(doc, &block)
      else
        raise ArgumentError, "Expected Hash, String path, or nil, got #{schema_or_path.class}"
      end
    end

    def generate_schema(doc, &block)
      schema_class = Class.new(RubyLLM::Schema)
      schema_class.class_eval(&block)

      requirements = schema_class.new.to_json

      generator = SchemaGenerator.new
      generator.generate(doc, requirements)
    end

    def generate_and_save_schema(doc, path, &block)
      xpath_schema = generate_schema(doc, &block)
      File.write(path, JSON.pretty_generate(xpath_schema))
      xpath_schema
    end
  end
end

# DSL method - allows Nukitori(html) { ... } syntax
def Nukitori(html, schema_or_path = nil, &block)
  Nukitori.call(html, schema_or_path, &block)
end
