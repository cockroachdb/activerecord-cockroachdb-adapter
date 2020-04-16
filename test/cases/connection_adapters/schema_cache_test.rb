require "cases/helper_cockroachdb"

module CockroachDB
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase

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

      private

        def schema_dump_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end
    end
  end
end
