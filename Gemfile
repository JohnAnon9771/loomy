# frozen_string_literal: true

source 'https://rubygems.org'

# Runtime dependencies come from the gemspec.
gemspec

group :development, :test do
  gem 'benchmark-ips', '~> 2.14'
  gem 'minitest', '~> 6.0'
  gem 'rake', '~> 13.0'
end

# Analysis tools only. Kept in their own group so the test matrix does not have
# to install them: they carry the widest dependency trees and the highest Ruby
# floors, and a tool raising its floor should not decide which Rubies the
# library itself can be tested on.
group :lint do
  gem 'rubocop', '~> 1.86'
  gem 'rubycritic', '~> 5.0', require: false
end
