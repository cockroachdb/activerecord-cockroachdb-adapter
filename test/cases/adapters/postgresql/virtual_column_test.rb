# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_virtual_columns?
  class PostgresqlVirtualColumnTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    self.use_transactional_tests = false

    def test_schema_dumping
      output = dump_table_schema("virtual_columns")
      assert_match(/t\.virtual\s+"upper_name",\s+type: :string,\s+as: nil, stored: true$/i, output)
      assert_match(/t\.virtual\s+"name_length",\s+type: :integer,\s+as: "length\(\(name\)::text\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"name_octet_length",\s+type: :integer,\s+as: "octet_length\(\(name\)::text\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"column2",\s+type: :integer,\s+as: "\(column1 \+ 1\)", stored: true$/i, output)
    end
  end
end
