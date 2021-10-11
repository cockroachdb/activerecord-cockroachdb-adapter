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

if ENV['COCKROACH_LOAD_FROM_TEMPLATE'].nil? && ENV['COCKROACH_SKIP_LOAD_SCHEMA'].nil?
  load_cockroachdb_specific_schema
elsif ENV['COCKROACH_LOAD_FROM_TEMPLATE']
  require 'support/template_creator'

  p "loading schema from template"

  # load from template
  TemplateCreator.restore_from_template

  # reconnect to activerecord_unittest
  ARTest.connect
end

require 'timeout'

module TestTimeoutHelper
  def time_it
    t0 = Minitest.clock_time

    Timeout.timeout(180, Timeout::Error, 'Test took over 3 minutes to finish') do
      yield
    end
  ensure
    self.time = Minitest.clock_time - t0
  end
end

module ActiveSupport
  class TestCase
    include TestTimeoutHelper

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

module ARTestCaseHelper
  def with_cockroachdb_datetime_type(type)
    adapter = ActiveRecord::ConnectionAdapters::CockroachDBAdapter
    adapter.remove_instance_variable(:@native_database_types) if adapter.instance_variable_defined?(:@native_database_types)
    datetime_type_was = adapter.datetime_type
    adapter.datetime_type = type
    yield
  ensure
    adapter = ActiveRecord::ConnectionAdapters::CockroachDBAdapter
    adapter.datetime_type = datetime_type_was
    adapter.remove_instance_variable(:@native_database_types) if adapter.instance_variable_defined?(:@native_database_types)
  end
end

ActiveRecord::TestCase.include(ARTestCaseHelper)
