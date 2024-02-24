require 'bundler'
Bundler.setup

CRDB_VALIDATE_BUG = "CockcroachDB bug, see https://github.com/cockroachdb/cockroach/blob/dd1e0e0164cb3d5859ea4bb23498863d1eebc0af/pkg/sql/alter_table.go#L458-L467"
require "minitest/excludes"
require "minitest/github_action_reporter"

# This gives great visibility on schema dump related tests, but
# some rails specific messages are then ignored.
Minitest::Test.make_my_diffs_pretty! if ENV['VERBOSE']

# Turn on debugging for the test environment
ENV['DEBUG_COCKROACHDB_ADAPTER'] = "1"

# Override the load_schema_helper for the
# two ENV variables COCKROACH_LOAD_FROM_TEMPLATE
# and COCKROACH_SKIP_LOAD_SCHEMA that can
# skip this step
require "support/load_schema_helper"
module LoadSchemaHelperExt
  def load_schema
    return if ENV['COCKROACH_LOAD_FROM_TEMPLATE']
    return if ENV['COCKROACH_SKIP_LOAD_SCHEMA']

    super
  end
end
LoadSchemaHelper.prepend(LoadSchemaHelperExt)

require "active_record"
require "active_record/connection_adapters"
require "active_record/connection_adapters/postgresql/schema_statements"
require "active_record/connection_adapters/cockroachdb/schema_statements"

# Disable foreign_keys altogether.
ActiveRecord::ConnectionAdapters::CockroachDB::SchemaStatements.prepend(Module.new do
  def add_foreign_key(*)
  end
end)


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

    timeout_mins = 5
    Timeout.timeout(timeout_mins * 60, Timeout::Error, "Test took over #{timeout_mins} minutes to finish") do
      yield
    end
  ensure
    self.time = Minitest.clock_time - t0
  end
end

# Retry tests that fail due to foreign keys not always being removed synchronously
# in disable_referential_integrity, which causes foreign key errors during
# fixutre creation.
#
# Can be removed once cockroachdb/cockroach#71496 is resolved.
module TestRetryHelper
  def run_one_method(klass, method_name, reporter)
    reporter.prerecord(klass, method_name)
    final_res = nil
    2.times do
      res = Minitest.run_one_method(klass, method_name)
      final_res ||= res

      retryable = false
      if res.error?
        res.failures.each do |f|
          retryable = true if f.message.include?("ActiveRecord::InvalidForeignKey")
        end
      end
      (final_res = res) && break unless retryable
    end

    # report message from first failure or from success
    reporter.record(final_res)
  end
end

module ActiveSupport
  class TestCase
    extend TestRetryHelper
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

module Minitest
  module GithubActionReporterExt
    def gh_link(loc)
      return super unless loc.include?("/gems/")

      path, _, line = loc[%r(/(?:test|spec|lib)/.*)][1..].rpartition(":")

      rails_version = "v#{ActiveRecord::VERSION::STRING}"
      "#{ENV["GITHUB_SERVER_URL"]}/rails/rails/blob/#{rails_version}/activerecord/#{path}#L#{line}"
    rescue
      warn "Failed to generate link for #{loc}"
      super
    end
  end
  GithubActionReporter.prepend(GithubActionReporterExt)
end

if ENV['AR_LOG']
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.logger.level = Logger::DEBUG
  ActiveRecord::Base.logger.formatter = proc { |severity, time, progname, msg|
    th = Thread.current[:name]
    th = "THREAD=#{th}" if th
    Logger::Formatter.new.call(severity, time, progname || th, msg)
  }
end

# Remove the header from the schema dump to clarify tests outputs.
module NoHeaderExt
  def header(stream)
    with_comments = StringIO.new
    super(with_comments)
    stream.print with_comments.string.gsub(/^(:?#.*)?\n/, '')
  end
end

ActiveRecord::SchemaDumper.prepend(NoHeaderExt)


ActiveSupport::Notifications.subscribe 'sql.active_record' do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  sql = event.payload[:sql]
  duration = event.duration # ms

  File.open("sql.ljson", "a") do |f|
    f.puts JSON.dump({sql: sql, duration: duration})
  end
end
