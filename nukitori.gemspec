# frozen_string_literal: true

require_relative "lib/nukitori/version"

Gem::Specification.new do |spec|
  spec.name = "nukitori"
  spec.version = Nukitori::VERSION
  spec.authors = ["Victor Afanasev"]
  spec.email = ["vicfreefly@gmail.com"]

  spec.summary = "The missing Ruby web scraping gem for the AI era"
  spec.description = "LLM-powered HTML data extraction. Define what you want, get XPath schema auto-generated, extract data from similar pages without AI."
  spec.homepage = "https://github.com/vifreefly/nukitori"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", '~> 1.19'
  spec.add_dependency "ruby_llm", '~> 1.9'
end
