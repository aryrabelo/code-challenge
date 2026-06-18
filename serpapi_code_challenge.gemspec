# frozen_string_literal: true

require_relative "lib/serpapi_code_challenge/version"

Gem::Specification.new do |spec|
  spec.name        = "serpapi_code_challenge"
  spec.version     = SerpapiCodeChallenge::VERSION
  spec.authors     = ["Ary Rabelo"]
  spec.summary     = "Extract the Google knowledge-graph artworks carousel from a SERP HTML page."
  spec.description = "Solution to the SerpApi 'Extract Van Gogh Paintings' code challenge. " \
                     "Parses a saved Google search results page (no extra HTTP requests) and returns " \
                     "the artworks carousel as an array of { name, extensions, link, image }."
  spec.homepage    = "https://github.com/aryrabelo/serpapi-code-challenge"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 2.6"

  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", ">= 1.13"

  spec.add_development_dependency "rspec",   "~> 3.13"
end
