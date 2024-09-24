# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

module CockroachDB
  if ActiveRecord::Base.lease_connection.supports_virtual_columns?
    class PostgresqlVirtualColumnTest < ActiveRecord::PostgreSQLTestCase
      include SchemaDumpingHelper

      self.use_transactional_tests = false

      class VirtualColumn < ActiveRecord::Base
      end

      def setup
        @connection = ActiveRecord::Base.lease_connection
        @connection.create_table :virtual_columns, force: true do |t|
          t.string  :name
          t.virtual :upper_name,  type: :string,  as: "UPPER(name)", stored: true
          t.virtual :name_length, type: :integer, as: "LENGTH(name)", stored: true
          t.virtual :name_octet_length, type: :integer, as: "OCTET_LENGTH(name)", stored: true
          t.integer :column1
          t.virtual :column2, type: :integer, as: "column1 + 1", stored: true
        end
        VirtualColumn.create(name: "Rails")
      end

      # TODO: is this test result acceptable?
      def test_schema_dumping
        output = dump_table_schema("virtual_columns")
        assert_match(/t\.virtual\s+"upper_name",\s+type: :string,\s+as: "upper\(name\)", stored: true$/i, output)
        assert_match(/t\.virtual\s+"name_length",\s+type: :bigint,\s+as: "length\(name\)", stored: true$/i, output)
        assert_match(/t\.virtual\s+"name_octet_length",\s+type: :bigint,\s+as: "octet_length\(name\)", stored: true$/i, output)
        assert_match(/t\.virtual\s+"column2",\s+type: :bigint,\s+as: "column1 \+ 1", stored: true$/i, output)
      end
    end
  end
end
