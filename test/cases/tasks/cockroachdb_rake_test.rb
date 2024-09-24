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
        ActiveRecord::Base.lease_connection.execute(<<~SQL)
          CREATE TYPE IF NOT EXISTS status AS ENUM ('open', 'closed', 'inactive');
        SQL
        assert_called(
          ActiveRecord::SchemaDumper,
          :ignore_tables,
          returns: ["accounts", "articles"]
        ) do
          ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, @filename)
        end
      ensure
        ActiveRecord::Base.lease_connection.execute(<<~SQL)
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

  class CockroachDBStructureLoadTest < ActiveRecord::TestCase
    def setup
      @configuration = {
        adapter: "cockroachdb",
        database: "my-app-db",
        host: "localhost"
      }
    end

    def test_structure_load
      filename = "awesome-file.sql"
      assert_called_with(
        Kernel,
        :system,
        [
          {"COCKROACH_INSECURE"=>"true", "COCKROACH_URL"=>"postgres://localhost/my-app-db"},
          "cockroach", "sql", "--set", "errexit=false", "--file", filename
        ],
        returns: true
      ) do
        ActiveRecord::Tasks::DatabaseTasks.structure_load(@configuration, filename)
      end
    end

    def test_url_generation
      assert_correct_url @configuration.merge(
        %i(sslmode sslrootcert sslcert sslkey).to_h { [_1, "v#{_1}"] }
      ), "postgres://localhost/my-app-db?sslmode=vsslmode&sslrootcert=vsslrootcert&sslcert=vsslcert&sslkey=vsslkey"
      assert_correct_url @configuration.merge({
        username: "root",
        port: 1234
      }), "postgres://root@localhost:1234/my-app-db"
      assert_correct_url @configuration.merge({
        username: "root",
        password: "secret"
      }), "postgres://root:secret@localhost/my-app-db"
    end

    private

    # Verify that given a config we generate the expected connection URL,
    # and that if we parse it again, we get the same config. Except the
    # `adapter` key, that'll changed to postgresql as the url given to
    # `cockroach sql` must start with the `postrges://` scheme.
    def assert_correct_url(config, expected_url)
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("default_env", "primary", config)
      task_chief = ActiveRecord::ConnectionAdapters::CockroachDB::DatabaseTasks.new(db_config)
      generated_url = task_chief.send(:cockroach_env)["COCKROACH_URL"]

      conf_from_generated_url = ActiveRecord::Base.
        configurations.
        resolve(generated_url).
        configuration_hash
      assert_equal expected_url, generated_url
      assert_equal config.except(:adapter), conf_from_generated_url.except(:adapter)
    end
  end
end
