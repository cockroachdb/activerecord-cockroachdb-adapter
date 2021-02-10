# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

module CockroachDB
  module PostgresqlUUIDHelper
    def connection
      @connection ||= ActiveRecord::Base.connection
    end

    def drop_table(name)
      connection.drop_table name, if_exists: true
    end

    def uuid_function
      connection.supports_pgcrypto_uuid? ? "gen_random_uuid()" : "uuid_generate_v4()"
    end

    def uuid_default
      connection.supports_pgcrypto_uuid? ? {} : { default: uuid_function }
    end
  end

  class PostgresqlUUIDTest < ActiveRecord::PostgreSQLTestCase
    include PostgresqlUUIDHelper
    include SchemaDumpingHelper

    class UUIDType < ActiveRecord::Base
      self.table_name = "uuid_data_type"
    end

    setup do
      enable_extension!("uuid-ossp", connection)
      enable_extension!("pgcrypto",  connection) if connection.supports_pgcrypto_uuid?

      connection.create_table "uuid_data_type" do |t|
        t.uuid "guid"
      end
    end

    teardown do
      drop_table "uuid_data_type"
    end


    # This test case is nearly identical to the ActiveRecord test, except that
    # the input guid is a valid UUID since CockroachDB will raise an exception
    # if the UUID is invalid whereas Postgres won't.
    def test_uuid_change_case_does_not_mark_dirty
      model = UUIDType.create!(guid: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11")
      model.guid = model.guid.swapcase
      assert_not_predicate model, :changed?
    end
  end
end
