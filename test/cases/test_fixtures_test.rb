# frozen_string_literal: true

require "cases/helper"
require "tempfile"
require "fileutils"
require "models/zine"
module CockroachDB
  class TestFixturesTest < ActiveRecord::TestCase
    setup do
      @klass = Class.new
      @klass.include(ActiveRecord::TestFixtures)
    end

    # This is identical to the Rails version, except that we set
    # use_transactional_tests to false. This is necessary because otherwise
    # the fixtures are created inside of a transaction, which causes a
    # DuplicateKey error and ultimately an InFailedSqlTransaction error.
    # Setting transactional tests to false allows the schema to update so that
    # we do not have an erroneous DuplicateKey error when re-creating the
    # foreign keys.
    self.use_transactional_tests = false

    unless in_memory_db?
      def test_doesnt_rely_on_active_support_test_case_specific_methods_with_legacy_connection_handling
        old_value = ActiveRecord.legacy_connection_handling
        ActiveRecord.legacy_connection_handling = true

        tmp_dir = Dir.mktmpdir
        File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
        going_out:
          title: Hello
        YML

        klass = Class.new(Minitest::Test) do
          include ActiveRecord::TestFixtures

          self.fixture_path = tmp_dir

          fixtures :all

          def test_run_successfully
            assert_equal("Hello", Zine.first.title)
            assert_equal("Hello", zines(:going_out).title)
          end
        end

        old_handler = ActiveRecord::Base.connection_handler
        ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
        assert_deprecated do
          ActiveRecord::Base.connection_handlers = {}
        end
        ActiveRecord::Base.establish_connection(:arunit)

        test_result = klass.new("test_run_successfully").run
        assert_predicate(test_result, :passed?)
      ensure
        clean_up_legacy_connection_handlers
        ActiveRecord::Base.connection_handler = old_handler
        FileUtils.rm_r(tmp_dir)
        ActiveRecord.legacy_connection_handling = old_value
      end

      def test_doesnt_rely_on_active_support_test_case_specific_methods
        tmp_dir = Dir.mktmpdir
        File.write(File.join(tmp_dir, "zines.yml"), <<~YML)
        going_out:
          title: Hello
        YML

        klass = Class.new(Minitest::Test) do
          include ActiveRecord::TestFixtures

          self.fixture_path = tmp_dir

          fixtures :all

          def test_run_successfully
            assert_equal("Hello", Zine.first.title)
            assert_equal("Hello", zines(:going_out).title)
          end
        end

        old_handler = ActiveRecord::Base.connection_handler
        ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
        ActiveRecord::Base.establish_connection(:arunit)

        test_result = klass.new("test_run_successfully").run
        assert_predicate(test_result, :passed?)
      ensure
        ActiveRecord::Base.connection_handler = old_handler
        clean_up_connection_handler
        FileUtils.rm_r(tmp_dir)
      end
    end
  end
end
