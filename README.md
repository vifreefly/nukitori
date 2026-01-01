# Nukitori

The missing Ruby web scraping gem for the AI era. Define what you want, get XPath schema auto-generated, extract data from similar pages without AI.

- **Nukitori = Nokogiri + AI** — smart HTML extraction powered by LLMs
- **One-time LLM call** — generates XPath schema once, then extracts data without AI on similar pages
- **Any LLM provider** — works with OpenAI, Anthropic, Gemini, and local models via RubyLLM

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

```ruby
# Without caching (generates schema each time)
data = Nukitori(html) do
  array :products do
    object do
      string :title
      number :price
    end
  end
end
```

```ruby
# With pre-made XPath schema hash
data = Nukitori(html, my_xpath_schema)
```

### Extended Usage

For more control, use the classes directly:

```ruby
require 'nukitori'
require 'ruby_llm/schema'

# Define requirements schema
class ReposSchema < RubyLLM::Schema
  array :repos do
    object do
      string :name
      string :url
      number :stars
    end
  end
end

# Generate XPath schema (uses LLM)
doc = Nokogiri::HTML(html)
generator = Nukitori::SchemaGenerator.new
xpath_schema = generator.generate(doc, ReposSchema.new.to_json)

# Save for reuse
File.write('xpath_schema.json', JSON.pretty_generate(xpath_schema))

# Extract data (no LLM)
extractor = Nukitori::Extractor.new(xpath_schema)
data = extractor.extract(doc)
```

### With Custom Model

```ruby
generator = Nukitori::SchemaGenerator.new(model: 'claude-sonnet-4')
xpath_schema = generator.generate(doc, requirements)
```

## How It Works

1. **You define** what data to extract using RubyLLM::Schema DSL
2. **LLM generates** XPath expressions that locate that data in HTML
3. **Extractor uses** those XPaths to pull data from any similar page

```
HTML + Schema Definition → LLM → XPath Schema → Extractor → Data
     (once)                         (reusable)      (no AI)
```

## Model Benchmarks

Tested on https://github.com/scrapy/scrapy page:

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

## License

MIT
