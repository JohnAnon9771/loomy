# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

namespace :test do
  desc 'Regenerate the golden reference images (review the PNGs before committing)'
  task :baseline do
    warn "\e[33m!! Baseline mode: golden references in test/assets/references will be OVERWRITTEN.\e[0m"
    warn "\e[33m!! Inspect `git diff --stat test/assets/references` and the PNGs before committing.\e[0m"
    warn ''

    ENV['LOOMY_BASELINE'] = '1'
    Rake::Task['test'].invoke
  end
end

task default: :test
