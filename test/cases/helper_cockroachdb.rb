require 'bundler'
Bundler.setup

module ExcludeMessage
  VALIDATE_BUG = "CockcroachDB bug, see https://github.com/cockroachdb/cockroach/blob/dd1e0e0164cb3d5859ea4bb23498863d1eebc0af/pkg/sql/alter_table.go#L458-L467"
  NO_HSTORE = "Extension \"hstore\" is not yet supported by CRDB. See https://github.com/cockroachdb/cockroach/issues/41284"
end

require "minitest/excludes"

# This gives great visibility on schema dump related tests, but
# some rails specific messages are then ignored.
Minitest::Test.make_my_diffs_pretty! if ENV['VERBOSE']

# Override the load_schema_helper for the
# two ENV variables COCKROACH_LOAD_FROM_TEMPLATE
# and COCKROACH_SKIP_LOAD_SCHEMA that can
# skip this step
require "support/load_schema_helper"

module LoadSchemaHelperExt
  # Load the CockroachDB specific schema. It replaces ActiveRecord's PostgreSQL
  # specific schema.
  def load_cockroachdb_specific_schema
    # silence verbose schema loading
    shh do
      load "schema/cockroachdb_specific_schema.rb"

      ActiveRecord::FixtureSet.reset_cache
    end
  end

  def load_schema
    return if ENV['COCKROACH_SKIP_LOAD_SCHEMA']
    return load_from_template { super } if ENV['COCKROACH_LOAD_FROM_TEMPLATE']

    print "Loading schema..."
    t0 = Time.now
    super
    load_cockroachdb_specific_schema
    puts format(" %.2fs", Time.now - t0)
    return
  end

  private def load_from_template(&)
    require 'support/template_creator'

    if TemplateCreator.template_exists?
      print "Loading schema from template..."
    else
      print "Generating and caching template schema..."
    end

    t0 = Time.now

    TemplateCreator.load_from_template do
      yield
      load_cockroachdb_specific_schema
    end

    puts format(" %.2fs", Time.now - t0)

    # reconnect to activerecord_unittest
    shh { ARTest.connect }
  end

  private def shh
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end
end
LoadSchemaHelper.prepend(LoadSchemaHelperExt)

require "activerecord-cockroachdb-adapter"

# Load ActiveRecord test helper
require "cases/helper"

require "support/exclude_from_transactional_tests"

# Allow exclusion of tests by name using #exclude_from_transactional_tests(test_name)
ActiveRecord::TestCase.prepend(ExcludeFromTransactionalTests)

require 'timeout'

module TestTimeoutHelper
  def time_it
    t0 = Minitest.clock_time

    timeout_mins = ENV.fetch("TEST_TIMEOUT", 5).to_i
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

      retryable = res.error? && res.failures.any? { _1.message.include?("ActiveRecord::InvalidForeignKey") }
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
      @postgis_version ||= ActiveRecord::Base.lease_connection.select_value('SELECT postgis_lib_version()')
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

module SetDatetimeInCockroachDBAdapter
  def with_postgresql_datetime_type(type)
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
  alias :with_cockroachdb_datetime_type :with_postgresql_datetime_type
end

ActiveRecord::TestCase.prepend(SetDatetimeInCockroachDBAdapter)

if ENV["JSON_REPORTER"]
  puts "Generating JSON report: #{ENV["JSON_REPORTER"]}"
  module Minitest
    class JSONReporter < StatisticsReporter
      def report
        super
        io.write(
          {
            seed: Minitest.seed,
            assertions: assertions,
            count: count,
            failed_tests: results.reject(&:skipped?),
            total_time: total_time,
            failures: failures,
            errors: errors,
            warnings: warnings,
            skips: skips,
          }.to_json
        )
      end
    end

    def self.plugin_json_reporter_init(*)
      reporter << JSONReporter.new(File.open(ENV["JSON_REPORTER"], "w"))
    end

    self.extensions << "json_reporter"
  end
end

# Using '--fail-fast' may cause the rails plugin to raise Interrupt when recording
# a test. This would prevent other plugins from recording it. Hence we make sure
# that rails plugin is loaded last.
Minitest.load_plugins
if Minitest.extensions.include?("rails")
  Minitest.extensions.delete("rails")
  Minitest.extensions << "rails"
end

if ENV['TRACE_LIB']
  module TraceLibPlugin
    def after_setup
      super
      @tl_plugin__already_showed = {}
      @tl_plugin__trace = TracePoint.new(:call) do |tp|
          next unless tp.path.include?("activerecord-cockroachdb-adapter/lib")
          full_path = "#{tp.path}:#{tp.lineno}"
          next if @tl_plugin__already_showed[full_path]
          @tl_plugin__already_showed[full_path] = true
          puts "==> #{tp.defined_class}##{tp.method_id} at #{full_path}"
      end
      @tl_plugin__trace.enable
    end

    def before_teardown
      @tl_plugin__trace.disable
      super
    end
  end
  Minitest::Test.include(TraceLibPlugin)
end

# Log all SQL queries and print total time spent in SQL.
if ENV["AR_LOG"]
  require "support/sql_logger"
  case ENV["AR_LOG"].strip
  when "stdout" then SQLLogger.stdout_log
  when "summary" then SQLLogger.summary_log
  else
    SQLLogger.stdout_log
    SQLLogger.summary_log
  end

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

# CRDB does not support ALTER COLUMN TYPE inside a transaction
# NOTE: This would be better in an exclude test, however this base
#   class is used by a lot of inherited tests. We repeat less here.
class BaseCompatibilityTest < ActiveRecord::TestCase
  self.use_transactional_tests = false
end
