# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'loomy/version'

# Ship the library and its docs; leave the test suite, benchmark and CI
# plumbing out of the packaged gem.
EXCLUDED_FROM_GEM = %r{
  \A(?:test|spec|features|assets|\.github)/ |
  \A(?:bench\.rb|Rakefile|Gemfile|Gemfile\.lock|\.rubocop\.yml|\.gitignore)\z
}x

Gem::Specification.new do |spec|
  spec.name          = 'loomy'
  spec.version       = Loomy::VERSION
  spec.authors       = ['João Alves']
  spec.email         = ['njoao97710@gmail.com']

  spec.summary       = 'Declarative image composition DSL using libvips'
  spec.description   = 'Loomy is a high-performance, declarative Ruby DSL for image composition and manipulation.'
  spec.homepage      = 'https://github.com/JohnAnon9771/loomy'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.2.0')

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").grep_v(EXCLUDED_FROM_GEM)
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'ruby-vips', '~> 2.3'
  spec.add_dependency 'zeitwerk', '~> 2.7'
end
