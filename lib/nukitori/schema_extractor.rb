# frozen_string_literal: true

module Nukitori
  class SchemaExtractor
    attr_reader :schema

    # @param schema [Hash] XPath schema
    def initialize(schema)
      @schema = deep_stringify_keys(schema)
    end

    # Extract data from HTML using the XPath schema
    # @param html [String, Nokogiri::HTML::Document] HTML string or Nokogiri document
    # @return [Hash] Extracted data
    def extract(html)
      doc = html.is_a?(Nokogiri::HTML::Document) ? html : Nokogiri::HTML(html)
      extract_fields(doc, schema)
    end

    private

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), result|
          result[k.to_s] = deep_stringify_keys(v)
        end
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end

    def extract_fields(context, fields)
      result = {}
      fields.each do |field_name, field_def|
        result[field_name] = extract_field(context, field_def)
      end
      result
    end

    def extract_field(context, field_def)
      return nil if field_def.is_a?(String)

      case field_def['type']
      when 'array'
        extract_array(context, field_def)
      when 'object'
        extract_object(context, field_def)
      else
        extract_primitive(context, field_def) if field_def['xpath']
      end
    end

    def extract_array(context, field_def)
      container_xpath = field_def['container_xpath']
      items_def = field_def['items']

      return [] unless container_xpath && items_def

      containers = context.xpath(container_xpath)

      # Simple array (strings) vs array of objects
      if items_def['xpath']
        containers.map { |c| extract_primitive(c, items_def) }
      else
        containers.map { |c| extract_fields(c, items_def) }
      end
    end

    def extract_object(context, field_def)
      properties = field_def['properties']
      context_xpath = field_def['context_xpath']

      if context_xpath
        context = context.at_xpath(context_xpath)
        return nil unless context
      end

      extract_fields(context, properties)
    end

    def extract_primitive(context, field_def)
      xpath = field_def['xpath']
      type = field_def['type'] || 'string'

      return nil unless xpath

      result = context.xpath(xpath)
      raw_value = extract_raw_value(result)

      return nil if raw_value.nil?

      convert_to_type(raw_value, type)
    end

    def extract_raw_value(xpath_result)
      return nil if xpath_result.nil?
      return nil if xpath_result.is_a?(Nokogiri::XML::NodeSet) && xpath_result.empty?

      value = if xpath_result.is_a?(Nokogiri::XML::NodeSet)
        node = xpath_result.first
        node.is_a?(Nokogiri::XML::Attr) ? node.value : node.text
      else
        xpath_result.to_s
      end

      value.strip
    end

    def convert_to_type(value, type)
      case type
      when 'string'
        value.to_s.gsub(/\s+/, ' ').strip
      when 'integer'
        value.gsub(/[^\d\-]/, '').to_i
      when 'number', 'float'
        value.gsub(/[^\d.\-]/, '').to_f
      when 'boolean'
        %w[true yes 1 on].include?(value.to_s.downcase)
      else
        value
      end
    end
  end
end
