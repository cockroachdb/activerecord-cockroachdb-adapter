require "cases/helper_cockroachdb"

module CockroachDB
  class PostgresqlActiveSchemaTest < ActiveRecord::PostgreSQLTestCase
    def setup
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
        def execute(sql, name = nil) sql end
      end
    end

    teardown do
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
        remove_method :execute
      end
    end

    # This replaces the same test that's been excluded from
    # PostgresqlActiveSchemaTest. It is almost exactly the same, but it excludes
    # assertions against partial indexes because they're not supported in
    # CockroachDB.
    # See test/excludes/PostgresqlActiveSchemaTest.rb
    def test_add_index
      # add_index calls index_name_exists? which can't work since execute is stubbed
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) { |*| false }

      expected = %(CREATE UNIQUE INDEX "index_people_on_lower_last_name" ON "people" (lower(last_name)))
      assert_equal expected, add_index(:people, "lower(last_name)", unique: true)

      expected = %(CREATE UNIQUE INDEX "index_people_on_last_name_varchar_pattern_ops" ON "people" (last_name varchar_pattern_ops))
      assert_equal expected, add_index(:people, "last_name varchar_pattern_ops", unique: true)

      expected = %(CREATE INDEX CONCURRENTLY "index_people_on_last_name" ON "people" ("last_name"))
      assert_equal expected, add_index(:people, :last_name, algorithm: :concurrently)

      expected = %(CREATE INDEX "index_people_on_last_name_and_first_name" ON "people" ("last_name" DESC, "first_name" ASC))
      assert_equal expected, add_index(:people, [:last_name, :first_name], order: { last_name: :desc, first_name: :asc })
      assert_equal expected, add_index(:people, ["last_name", :first_name], order: { last_name: :desc, "first_name" => :asc })

      %w(gin gist hash btree).each do |type|
        expected = %(CREATE INDEX "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
        assert_equal expected, add_index(:people, :last_name, using: type)

        expected = %(CREATE INDEX CONCURRENTLY "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
        assert_equal expected, add_index(:people, :last_name, using: type, algorithm: :concurrently)

        expected = %(CREATE UNIQUE INDEX "index_people_on_lower_last_name" ON "people" USING #{type} (lower(last_name)))
        assert_equal expected, add_index(:people, "lower(last_name)", using: type, unique: true)
      end

      expected = %(CREATE INDEX "index_people_on_last_name" ON "people" USING gist ("last_name" bpchar_pattern_ops))
      assert_equal expected, add_index(:people, :last_name, using: :gist, opclass: { last_name: :bpchar_pattern_ops })

      expected = %(CREATE INDEX "index_people_on_last_name_and_first_name" ON "people" ("last_name" DESC NULLS LAST, "first_name" ASC))
      assert_equal expected, add_index(:people, [:last_name, :first_name], order: { last_name: "DESC NULLS LAST", first_name: :asc })

      expected = %(CREATE INDEX "index_people_on_last_name" ON "people" ("last_name" NULLS FIRST))
      assert_equal expected, add_index(:people, :last_name, order: "NULLS FIRST")

      assert_raise ArgumentError do
        add_index(:people, :last_name, algorithm: :copy)
      end

      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send :remove_method, :index_name_exists?
    end

    private
      def method_missing(...)
        ActiveRecord::Base.lease_connection.send(...)
      end
  end
end
