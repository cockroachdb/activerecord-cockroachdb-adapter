require "cases/helper_cockroachdb"

module CockroachDB
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      def setup
        @connection = ActiveRecord::Base.connection
        @database_version = @connection.get_database_version
      end

      # This replaces the same test that's been excluded from
      # ActiveRecord::ConnectionAdapters::SchemaCacheTest. It's exactly the
      # same, but we can run it here by fixing schema_dump_path so it has a
      # valid path.
      # See test/excludes/ActiveRecord/ConnectionAdapters/SchemaCacheTest.rb
      def test_yaml_loads_5_1_dump
        body = File.open(schema_dump_path).read
        cache = YAML.load(body)

        assert_no_queries do
          assert_equal 11, cache.columns("posts").size
          assert_equal 11, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
        end
      end

      # This replaces the same test that's been excluded from
      # ActiveRecord::ConnectionAdapters::SchemaCacheTest. It's exactly the
      # same, but we can run it here by fixing schema_dump_path so it has a
      # valid path.
      # See test/excludes/ActiveRecord/ConnectionAdapters/SchemaCacheTest.rb
      def test_yaml_loads_5_1_dump_without_indexes_still_queries_for_indexes
        body = File.open(schema_dump_path).read
        @cache = YAML.load(body)

        # Simulate assignment in railtie after loading the cache.
        old_cache, @connection.schema_cache = @connection.schema_cache, @cache

        assert_queries :any, ignore_none: true do
          assert_equal 1, @cache.indexes("posts").size
        end
      ensure
        @connection.schema_cache = old_cache
      end

      # This replaces the same test that's been excluded from
      # ActiveRecord::ConnectionAdapters::SchemaCacheTest. It's exactly the
      # same, but we can run it here by fixing schema_dump_path so it has a
      # valid path.
      # See test/excludes/ActiveRecord/ConnectionAdapters/SchemaCacheTest.rb
      def test_yaml_loads_5_1_dump_without_database_version_still_queries_for_database_version
        body = File.open(schema_dump_path).read
        @cache = YAML.load(body)

        # Simulate assignment in railtie after loading the cache.
        old_cache, @connection.schema_cache = @connection.schema_cache, @cache

        # We can't verify queries get executed because the database version gets
        # cached in both MySQL and PostgreSQL outside of the schema cache.
        assert_nil @cache.instance_variable_get(:@database_version)
        assert_equal @database_version.to_s, @cache.database_version.to_s
      ensure
        @connection.schema_cache = old_cache
      end

      private

        def schema_dump_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end
    end
  end
end
