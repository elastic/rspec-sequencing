# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "rspec-sequencing"
  spec.version       = "0.1.1"
  spec.licenses      = ['Apache-2.0']
  spec.authors       = ["Elastic"]
  spec.email         = ["info@elastic.co"]

  spec.summary       = "Define sequenced actions that simulate real-world scenarios"
  spec.homepage      = "https://github.com/elastic/rspec-sequencing"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rspec", ">= 3.0.0"
  spec.add_runtime_dependency "concurrent-ruby"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
