# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/account"

module CockroachDB
  module ConnectionAdapters
    class TypeTest < ActiveRecord::TestCase
      fixtures :accounts
      class SqliteModel < ActiveRecord::Base
        establish_connection(
          adapter:  "sqlite3",
          database: "tmp/some"
        )
      end
      def test_type_can_be_used_with_various_db
        assert_equal(
          :postgresql,
          ActiveRecord::Type.adapter_name_from(Account)
        )
        assert_equal(
           :sqlite3,
           ActiveRecord::Type.adapter_name_from(SqliteModel)
        )
      end
    end
  end
end
