require 'bundler/setup'
Bundler.require :default, :development

# Turn on debugging for the test environment
ENV['DEBUG_COCKROACHDB_ADAPTER'] = "1"
