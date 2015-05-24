begin
  require 'rubygems'
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

APP_RAKEFILE = File.expand_path("../spec/dummy/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

Bundler::GemHelper.install_tasks

SUPPORTED_ADAPTERS = %w(postgresql mysql2)

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec, :adapter) do |t, task_args|
  adapter = task_args[:adapter] || 'postgresql'
  excluded_tags = SUPPORTED_ADAPTERS - [adapter]
  t.rspec_opts = "--tag ~#{excluded_tags.first}" if task_args.any?
end

RSpec::Core::RakeTask.new(:postgres_specs) do |t|
  excluded_tags = SUPPORTED_ADAPTERS - %w(postgresql)
  t.rspec_opts = "--tag ~#{excluded_tags.first}"
end

task :default => :postgres_specs
