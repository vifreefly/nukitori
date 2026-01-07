# Nukitori

<img align="right" height="175px" src="https://habrastorage.org/webt/cc/se/er/ccseeryjqt-rto5biycw4twgyue.png" alt="Nukitori gem logo" />

Nukitori is a Ruby gem for HTML data extraction that uses an LLM once to generate reusable XPath schemas, then extracts data using plain Nokogiri (without AI) from similarly structured HTML pages. You describe the data you want to extract; Nukitori generates and reuses the scraping logic for you:

- **One-time LLM call** — generates a reusable XPath schema; all subsequent extractions run without AI
- **Robust reusable schemas** — avoids page-specific IDs, dynamic hashes, and fragile selectors
- **Transparent output** — generated schemas are plain JSON, easy to inspect, diff, and version
- **Token-optimized** — strips scripts, styles, and redundant DOM before sending HTML to the LLM
- **Any LLM provider** — works with OpenAI, Anthropic, Gemini, and local models:

```ruby
# example_extract.rb
require 'nukitori'
require 'json'

html = "<HTML DOM from https://github.com/search?q=ruby+web+scraping&type=repositories>"

# define what you want to extract from HTML using simple DSL:
data = Nukitori(html, 'schema.json') do
  integer :repositories_found_count
  array :repositories do
    object do
      string :name
      string :description
      string :url
      string :stars
      array :tags, of: :string
    end
  end
end

File.write('results.json', JSON.pretty_generate(data))
```

On the first run `$ ruby example_extract.rb` Nukitori uses AI to generate a reusable XPath extraction schema:

```json
/* schema.json */
{
  "repositories_found_count": {
    "xpath": "//a[@data-testid='nav-item-repositories']//span[@data-testid='resolved-count-label']",
    "type": "integer"
  },
  "repositories": {
    "type": "array",
    "container_xpath": "//div[@data-testid='results-list']/*[.//div[contains(@class, 'search-title')]]",
    "items": {
      "name": {
        "xpath": ".//div[contains(@class, 'search-title')]//a",
        "type": "string"
      },
      "description": {
        "xpath": ".//h3/following-sibling::div[1]",
        "type": "string"
      },
      "url": {
        "xpath": ".//div[contains(@class, 'search-title')]//a/@href",
        "type": "string"
      },
      "stars": {
        "xpath": ".//a[contains(@href, '/stargazers')]",
        "type": "string"
      },
      "tags": {
        "type": "array",
        "container_xpath": ".//a[contains(@href, '/topics/')]",
        "items": {
          "xpath": ".",
          "type": "string"
        }
      }
    }
  }
}
```

After that, Nukitori extracts structured data from similar HTMLs without any LLM calls, in milliseconds:

```json
/* results.json */
{
  "repositories_found_count": 314,
  "repositories": [
    {
      "name": "sparklemotion/mechanize",
      "description": "Mechanize is a ruby library that makes automated web interaction easy.",
      "url": "/sparklemotion/mechanize",
      "stars": "4.4k",
      "tags": ["ruby", "web", "scraping"]
    },
    {
      "name": "jaimeiniesta/metainspector",
      "description": "Ruby gem for web scraping purposes. It scrapes a given URL, and returns you its title, meta description, meta keywords, links, images...",
      "url": "/jaimeiniesta/metainspector",
      "stars": "1k",
      "tags": []
    },
    {
      "name": "vifreefly/kimuraframework",
      "description": "Kimurai is a modern Ruby web scraping framework designed to scrape and interact with JavaScript-rendered websites using headless antidete…",
      "url": "/vifreefly/kimuraframework",
      "stars": "1.1k",
      "tags": ["ruby", "crawler", "scraper", "web-scraping", "scrapy"]
    },
    //...
  ]
}
```

## Installation

`$ gem install nukitori` or add it to your Gemfile `gem 'nukitori'`. Required Ruby version is `3.2` and up.


## Configuration

```ruby
require 'nukitori'

Nukitori.configure do |config|
  config.default_model = 'gpt-5.2'
  config.openai_api_key = '<OPENAI_API_KEY>'

  # or
  config.default_model = 'claude-haiku-4-5-20251001'
  config.anthropic_api_key = '<ANTHROPIC_API_KEY>'
  
  # or
  config.default_model = 'gemini-3-flash-preview'
  config.gemini_api_key = '<GEMINI_API_KEY>'

  # or
  config.default_model = 'deepseek-chat'
  config.deepseek_api_key = '<DEEPSEEK_API_KEY>'
end
```

Using custom OpenAI API-compatible models (including local ones). Example with Z.AI:

```ruby
Nukitori.configure do |config|
  config.default_model = 'glm-4.7'

  config.openai_use_system_role = true # optionally, depends on API
  config.openai_api_base = 'https://api.z.ai/api/paas/v4/'
  config.openai_api_key = '<ZAI_API_KEY>'
end
```

## Usage

Use [format of RubyLLM::Schema](https://github.com/danielfriis/ruby_llm-schema) to define extraction schemas. Supported schema property types:
* `string` - type you should use in most cases
* `integer` - parses extracted string to Ruby's Integer
* `number` - parses extracted string value to Ruby's Float

Tip: if LLM having troubles to correctly find correct Xpath for a field, use `description` option to point out what exactly needs to be scraped for this field:

```ruby
data = Nukitori(html, 'product_schema.json') do
  string :name, description: 'Product name'
  string :availability, description: 'Product availability, in stock or out of stock'
  string :description, description: 'Short product description'
  string :manufacturer
  string :price
end
```

### Extended API

```ruby
require 'nukitori'

# Define extraction schema 
schema_generator = Nukitori::SchemaGenerator.new do
  array :products do
    object do
      string :name
      string :price
      string :availability
    end
  end
end

# Generate extraction schema (uses LLM), returns Ruby hash as schema
extraction_schema = schema_generator.create_extraction_schema_for(html)

# Optionally save for reuse to a file or a database
# File.write('extraction_schema.json', JSON.pretty_generate(extraction_schema))

# Extract data from HTML using previously generated extraction_schema (no LLM)
schema_extractor = Nukitori::SchemaExtractor.new(extraction_schema)
data = schema_extractor.extract(html)
```

### With Custom Model

```ruby
schema_generator = Nukitori::SchemaGenerator.new(model: 'claude-haiku-4-5-20251001') do
  string :title
  number :price
end

extraction_schema = schema_generator.create_extraction_schema_for(html)
```

### LLM-only extraction (no schemas)

Nukitori can also extract data directly with an LLM, without generating or using XPath schemas.
In this mode, every extraction call invokes the LLM and relies on its structured output capabilities.

This approach trades higher cost and latency for greater flexibility: the LLM can not only extract values from HTML, but also normalize, convert, and transform them based on the declared field types.

```ruby
# If no schema path is provided, Nukitori uses the LLM
# for data extraction on every run
data = Nukitori(html) do
  string  :repo_name
  number  :stars_count
end
```

<details>
  <summary>When LLM-only extraction is useful? (click to expand)</summary><br>

Consider scraping a GitHub repository page that shows 1.1k stars. With a reusable XPath schema, Nukitori extracts exactly what appears in the HTML.
If the value is rendered as `"1.1k"`, that is what the extractor receives.

```ruby
# XPath-based extraction (LLM used only once to generate the schema)
data = Nukitori(html, 'schema.json') do
  number :stars_count
end

# Result reflects the literal HTML value `1.1k` converted to float:
# => { "stars_count" => 1.1 }
```

To convert `"1.1k"` into `1100`, you would need to scrape in string `string :stars_count` and then add custom post-processing conversion logic.

With LLM-only extraction, Nukitori can define the intended numeric value directly:

```ruby
# LLM-only extraction (LLM called on every run)
data = Nukitori(html) do
  number :stars_count
end

# LLM interprets "1.1k" as 1100
# => { "stars_count" => 1100 }
```

**Pros**
* Flexible output schemas
* Automatic normalization and value conversion
* Useful for semantic or non-trivial transformations

**Cons**
* LLM call on every extraction
* Higher cost and latency
* Less deterministic than schema-based extraction

Use LLM-only extraction when you need semantic understanding or complex value normalization, or when running against cheap or local LLMs. For high-volume or long-running scrapers, reusable XPath schemas are usually the better choice.

</details>


## Model Benchmarks

Tested on current page's HTML DOM to generate following extraction schema:

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

**Recommendation:** Based on my testing, models like `gpt-5.2` or `gemini-3-flash-preview` offer the best balance of speed and reliability for generating complex nested extraction schemas. They consistently generate robust XPaths that work across similar HTML pages.

## Thanks to
* [Nokogiri](https://github.com/sparklemotion/nokogiri)
* [RubyLLM](https://github.com/crmne/ruby_llm)

## License

MIT
