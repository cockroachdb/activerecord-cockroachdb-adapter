require "bundler/gem_tasks"
require "rake/testtask"
require_relative 'test/support/paths_cockroachdb'
require_relative 'test/support/rake_helpers'

task default: [:test]

Rake::TestTask.new do |t|
  t.libs = ARTest::CockroachDB.test_load_paths
  t.test_files = RakeHelpers.test_files
  t.warning = !!ENV["WARNING"]
  t.verbose = false
end
