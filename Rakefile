require "bundler/gem_tasks"
require "rake/testtask"
require_relative 'test/support/paths_cockroachdb'
require_relative 'test/support/rake_helpers'
require_relative 'test/support/template_creator'

task default: [:test]

namespace :db do
  task "create_test_template" do
    ENV['DEBUG_COCKROACHDB_ADAPTER'] = "1"
    ENV['COCKROACH_SKIP_LOAD_SCHEMA'] = "1"

    TemplateCreator.connect
    require_relative 'test/cases/helper'

    # TODO: look into this more, but for some reason the blob alias
    # is not defined while running this task.
    ActiveRecord::ConnectionAdapters::CockroachDB::TableDefinition.class_eval do
      alias :blob :binary
    end

    TemplateCreator.create_test_template
  end
end

Rake::TestTask.new do |t|
  t.libs = ARTest::CockroachDB.test_load_paths
  t.test_files = RakeHelpers.test_files
  t.warning = !!ENV["WARNING"]
  t.verbose = false
end
