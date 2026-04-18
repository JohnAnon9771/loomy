# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'loomy/version'

Gem::Specification.new do |spec|
  spec.name          = 'loomy'
  spec.version       = Loomy::VERSION
  spec.authors       = ['João Alves']
  spec.email         = ['njoao97710@gmail.com']

  spec.summary       = 'Declarative image composition DSL using libvips'
  spec.description   = 'Loomy is a high-performance, declarative Ruby DSL for image composition and manipulation.'
  spec.homepage      = 'https://github.com/JohnAnon9771/loomy'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'ruby-vips', '~> 2.3'
  spec.add_dependency 'zeitwerk', '~> 2.7'

  spec.add_development_dependency 'minitest', '~> 6.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop', '~> 1.86'
end
