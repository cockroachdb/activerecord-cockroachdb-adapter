require "bundler/gem_tasks"
require "rake/testtask"
require_relative 'test/support/paths_cockroachdb'
require_relative 'test/support/rake_helpers'

task test: ["test:cockroachdb"]
task default: [:test]

namespace :test do
  Rake::TestTask.new("cockroachdb") do |t|
    t.libs = ARTest::CockroachDB.test_load_paths
    t.test_files = test_files
    t.warning = !!ENV["WARNING"]
    t.verbose = false
  end

  task "cockroachdb:env" do
    ENV["ARCONN"] = "cockroachdb"
  end
end

task 'test:cockroachdb' => 'test:cockroachdb:env'
