# frozen_string_literal: true

require "cases/helper"
require "active_record/tasks/database_tasks"
require "active_record/connection_adapters/cockroachdb/database_tasks"

module ActiveRecord
  class CockroachDBStructureDumpTest < ActiveRecord::TestCase
    def setup
      @configuration = {
        "adapter"  => "cockroachdb",
        "database" => "my-app-db"
      }
      @filename = "/tmp/awesome-file.sql"
      FileUtils.touch(@filename)
    end

    def teardown
      FileUtils.rm_f(@filename)
    end

    def test_structure_dump
      assert_equal "", File.read(@filename)
      File.write(@filename, "NOT TODAY\n")

      config = @configuration.dup
      config["database"] = ARTest.config["connections"]["cockroachdb"]["arunit"]["database"]

      begin
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE TYPE IF NOT EXISTS status AS ENUM ('open', 'closed', 'inactive');
        SQL
        assert_called(
          ActiveRecord::SchemaDumper,
          :ignore_tables,
          returns: ["accounts", "articles"]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, @filename)

          read = File.read(@filename)
        end
      ensure
        ActiveRecord::Base.connection.execute(<<~SQL)
          DROP TYPE IF EXISTS status;
        SQL
      end

      read = File.read(@filename)
      refute read.include?("NOT TODAY"), "The dump file previous content was not overwritten"
      assert read.include?("CREATE SCHEMA public;"), "Schemas are not dumped"
      assert read.include?("CREATE TYPE public.status AS ENUM ('open', 'closed', 'inactive');"), "Types are not dumped"
      assert read.include?("CREATE TABLE public.schema_migrations"), "No dump done"
      refute read.include?("CREATE TABLE public.articles ("), "\"articles\" table should be ignored"
      refute read.include?("CREATE TABLE public.accounts ("), "\"accounts\" table should be ignored"
    end
  end
end
