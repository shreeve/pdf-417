# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = "pdf-417"
  s.version     = "0.5.0"
  s.author      = "Steve Shreeve"
  s.email       = "steve.shreeve@gmail.com"
  s.summary     = "Generate PDF-417 barcodes"
  s.description = "Basic, text-only PDF-417 barcode generator."
  s.homepage    = "https://github.com/shreeve/pdf-417"
  s.license     = "MIT"
  s.platform    = Gem::Platform::RUBY
  s.files       = `git ls-files`.split("\n") - %w[.gitignore]
  s.add_runtime_dependency "chunky_png", "~> 0"
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
end
