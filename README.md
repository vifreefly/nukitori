# Nukitori

The missing web data extraction gem for Ruby in the AI era. Define what you want, get XPath schema auto-generated, extract data from similar pages without AI.

- **Nukitori = Nokogiri + AI** — smart HTML extraction powered by LLMs
- **One-time LLM call** — generates XPath schema once, then extracts data without AI on similar pages
- **Robust reusable schemas** — avoids page-specific IDs, dynamic hashes, and fragile selectors
- **Token-optimized** — strips scripts, styles, and redundant elements before sending to LLM
- **Any LLM provider** — works with OpenAI, Anthropic, Gemini, and local models via RubyLLM
- **Up-to-date models** — bundled models registry includes latest models (gpt-5.2, claude-sonnet-4, etc.)

## Installation

```ruby
gem 'nukitori'
```

## Configuration

```ruby
require 'nukitori'

Nukitori.configure do |config|
  config.default_model = 'gpt-5'
  config.openai_api_key = ENV['OPENAI_API_KEY']
  # or
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  # or
  config.gemini_api_key = ENV['GEMINI_API_KEY']
end
```

## Usage

### Simple DSL

```ruby
# With schema caching (recommended)
# First run: generates XPath schema via LLM, saves to file
# Next runs: loads schema from file (no LLM calls)
data = Nukitori(html, 'repos_schema.json') do
  string :total_count
  array :repos do
    object do
      string :name
      string :description
      string :url
      string :stars
      array :tags, of: :string
    end
  end
end

puts data['repos'].first['name']
```

### Extended Usage

For more control, use the classes directly:

```ruby
require 'nukitori'

# Define schema once
schema_generator = Nukitori::SchemaGenerator.new do
  array :repos do
    object do
      string :name
      string :url
      number :stars
    end
  end
end

# Generate extraction schema (uses LLM)
extraction_schema = schema_generator.create_extraction_schema_for(html)

# Save for reuse
File.write('extraction_schema.json', JSON.pretty_generate(extraction_schema))

# Extract data (no LLM)
data_extractor = Nukitori::DataExtractor.new(extraction_schema)
data = data_extractor.extract(html)
```

### With Custom Model

```ruby
schema_generator = Nukitori::SchemaGenerator.new(model: 'claude-sonnet-4') do
  string :title
  number :price
end

extraction_schema = schema_generator.create_extraction_schema_for(html)
```

## How It Works

1. **You define** what data to extract using simple schema DSL
2. **LLM generates** XPath expressions that locate that data in HTML
3. **Extractor uses** those XPaths to pull data from any similar page

```
HTML + Schema Definition → LLM → XPath Schema → Extractor → Data
     (once)                         (reusable)      (no AI)
```

## Model Benchmarks

Tested on https://github.com/scrapy/scrapy HTML DOM:

```ruby
data = Nukitori(html, 'schema.json') do
  string :name
  string :desc
  string :stars_count
  array :tags, of: :string
end
```

| Provider | Model | Time |
|----------|-------|------|
| OpenAI | `gpt-5.2` | ~7s |
| OpenAI | `gpt-5` | ~35s |
| OpenAI | `gpt-5-mini` | ~18s |
| OpenAI | `gpt-5-nano` | ~32s (may generate incomplete schemas) |
| Gemini | `gemini-3-flash-preview` | ~11s |
| Gemini | `gemini-3-pro-preview` | ~30s |
| Anthropic | `claude-opus-4-5-20251101` | ~6.5s |
| Anthropic | `claude-sonnet-4-5-20250929` | ~7s |
| Anthropic | `claude-haiku-4-5-20251001` | ~3.5s |
| DeepSeek | `deepseek-chat` (V3.2) | ~10s |
| Z.AI | `glm-4.7` | ~1m |
| Z.AI | `glm-4.5-airx` | ~30s |

**Recommendation:** Based on my testing, `gpt-5.2` offers the best balance of speed and reliability for generating complex nested extraction schemas. It consistently generates robust XPaths that work across similar HTML pages.

## License

MIT
