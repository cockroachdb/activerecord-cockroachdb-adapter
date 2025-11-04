# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "support/connection_helper" # for #reset_connection
require "support/copy_cat"

class CockroachDBReferentialIntegrityTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper

  module ProgrammerMistake
    def execute_batch(sql, name = nil)
      raise ArgumentError, "something is not right." if name.match?(/referential integrity/)
      super
    end
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    reset_connection
  end

  exclude_from_transactional_tests :test_only_catch_active_record_errors_others_bubble_up
  CopyCat.copy_methods(self, ::PostgreSQLReferentialIntegrityTest, :test_only_catch_active_record_errors_others_bubble_up)

  def test_should_reraise_invalid_foreign_key_exception_and_show_warning
    warning = capture(:stderr) do
      e = assert_raises(ActiveRecord::InvalidForeignKey) do
        @connection.disable_referential_integrity do
          @connection.execute("INSERT INTO authors (name, author_address_id) VALUES ('Mona Chollet', 42)")
        end
      end
      assert_match (/Key \(author_address_id\)=\(42\) is not present in table/), e.message
    end
    assert_match (/WARNING: Rails was not able to disable referential integrity/), warning
    assert_match (/autocommit_before_ddl/), warning
  end

  def test_no_warning_nor_error_with_autocommit_before_ddl
    @connection.execute("SET SESSION autocommit_before_ddl = 'on'")
    warning = capture(:stderr) do
      @connection.disable_referential_integrity do
        @connection.execute("INSERT INTO authors (name, author_address_id) VALUES ('Mona Chollet', 42)")
        @connection.truncate(:authors)
      end
    end
    assert_predicate warning, :blank?, "expected no warnings but got:\n#{warning}"
  end
end
