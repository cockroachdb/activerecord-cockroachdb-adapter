require 'bundler/setup'
Bundler.require :development

# Turn on debugging for the test environment
ENV['DEBUG_COCKROACHDB_ADAPTER'] = "1"

# Load ActiveRecord test helper
require "cases/helper"

# Load the CockroachDB specific schema. It replaces ActiveRecord's PostgreSQL
# specific schema.
def load_cockroachdb_specific_schema
  # silence verbose schema loading
  original_stdout = $stdout
  $stdout = StringIO.new

  load "schema/cockroachdb_specific_schema.rb"

  ActiveRecord::FixtureSet.reset_cache
ensure
  $stdout = original_stdout
end

load_cockroachdb_specific_schema

module ActiveSupport
  class TestCase
    def postgis_version
      @postgis_version ||= ActiveRecord::Base.connection.select_value('SELECT postgis_lib_version()')
    end

    def factory
      RGeo::Cartesian.preferred_factory(srid: 3857)
    end

    def geographic_factory
      RGeo::Geographic.spherical_factory(srid: 4326)
    end

    def spatial_factory_store
      RGeo::ActiveRecord::SpatialFactoryStore.instance
    end
  end
end
