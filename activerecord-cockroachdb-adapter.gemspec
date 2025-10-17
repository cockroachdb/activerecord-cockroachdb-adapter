# frozen_string_literal: true

require_relative 'lib/version'
version = ActiveRecord::COCKROACH_DB_ADAPTER_VERSION

Gem::Specification.new do |spec|
  spec.name          = "activerecord-cockroachdb-adapter"
  spec.version       = version
  spec.licenses      = ["Apache-2.0"]
  spec.authors       = ["Cockroach Labs"]
  spec.email         = ["cockroach-db@googlegroups.com"]

  spec.summary       = "CockroachDB adapter for ActiveRecord."
  spec.description   = "Allows the use of CockroachDB as a backend for ActiveRecord and Rails apps."
  spec.homepage      = "https://github.com/cockroachdb/activerecord-cockroachdb-adapter"

  spec.add_dependency "activerecord", "~> 8.1.0"
  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "rgeo-activerecord", "~> 8.1.0"

  spec.add_development_dependency "benchmark-ips", "~> 2.9.1"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  git_files = `git ls-files -z`.split("\x0")
  spec.files = (Dir["lib/**/*.rb"] + %w(LICENSE Rakefile Gemfile)) & git_files
  spec.extra_rdoc_files = Dir["**/*.md"] & git_files
  spec.test_files = Dir["test/**/*"] & git_files
end
