# frozen_string_literal: true

module Nukitori
  # Preprocesses HTML to reduce token size for LLM
  class HtmlPreprocessor
    # @param html [String, Nokogiri::HTML::Document] HTML string or Nokogiri document
    # @return [String] Cleaned HTML
    def self.process(html)
      doc = html.is_a?(Nokogiri::HTML::Document) ? html.dup : Nokogiri::HTML(html)

      # Remove non-content elements
      doc.css('script, style, noscript, svg, path, meta, link, head').remove

      # Remove style attributes
      doc.css('*').each { |node| node.remove_attribute('style') }

      # Collapse whitespace
      doc.to_html.gsub(/\s+/, ' ')
    end
  end
end
