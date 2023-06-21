# frozen_string_literal: true

source "https://rubygems.org"

gemspec


module RailsTag
  class << self
    def call
      req = gemspec_requirement
      "v" + all_activerecord_versions.find { req.satisfied_by?(_1) }.version
    end

    def gemspec_requirement
      File
        .foreach("activerecord-cockroachdb-adapter.gemspec", chomp: true)
        .find { _1[/add_dependency\s.activerecord.,\s.(.*)./] }

      Gem::Requirement.new(Regexp.last_match(1))
    end

    def all_activerecord_versions
      require 'net/http'
      require 'yaml'

      uri = URI.parse "https://rubygems.org/api/v1/versions/activerecord.yaml"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      YAML.load(
        http.request(Net::HTTP::Get.new(uri.request_uri)).body
      ).map { Gem::Version.new(_1["number"]) }
    end
  end
end


group :development, :test do
  # We need to load the gem from git to have access to activerecord's test files.
  # You can use `path: "some/local/rails"` if you want to test the gem against
  # a specific rails codebase.
  gem "rails", github: "rails/rails", tag: RailsTag.call

  gem "rake"
  gem "byebug"
  gem "minitest-excludes", "~> 2.0.1"

  # Gems used by the ActiveRecord test suite
  gem "bcrypt", "~> 3.1.18"
  gem "mocha", "~> 1.14.0"
  gem "sqlite3", "~> 1.4.4"

  gem "minitest", "~> 5.15.0"
end
