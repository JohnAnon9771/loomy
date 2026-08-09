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

# Score floor for the code-smell analysis. A ratchet, not an aspiration: it sits
# just under the current score so a real regression fails while ordinary
# variation does not. Raise it when the score rises, never lower it to make a
# build pass.
MINIMUM_CRITIC_SCORE = 90

desc 'Analyse code smells and open the HTML report'
task :critic do
  sh "bundle exec rubycritic lib --minimum-score #{MINIMUM_CRITIC_SCORE}"
end

namespace :critic do
  desc 'Analyse code smells and print to the terminal (no browser)'
  task :console do
    sh "bundle exec rubycritic lib --no-browser --format console --minimum-score #{MINIMUM_CRITIC_SCORE}"
  end
end

task default: :test
