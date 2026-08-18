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

  # `#disable_referential_integrity` drops and re-adds every foreign key using
  # batched DDL. CockroachDB cannot auto-unlock a `schema_locked` table for a
  # multi-statement batch, so the adapter must unlock the affected tables (both
  # the referencing and referenced ones) around the batch and restore their
  # locked state. This must run outside a transaction: the batched DDL only
  # takes the unlocking path when no transaction is open, and toggling
  # `schema_locked` is only allowed in single-statement implicit transactions.
  exclude_from_transactional_tests :test_disable_referential_integrity_unlocks_schema_locked_tables
  def test_disable_referential_integrity_unlocks_schema_locked_tables
    skip "schema_locked requires CockroachDB v25.3+" if @connection.database_version < 25_03_00

    # `authors.author_address_id` references `author_addresses`, so this covers
    # both the referencing and referenced sides of a foreign key.
    begin
      @connection.execute("ALTER TABLE authors SET (schema_locked = true)")
      @connection.execute("ALTER TABLE author_addresses SET (schema_locked = true)")
      assert schema_locked?(:authors), "precondition: authors should be schema_locked"
      assert schema_locked?(:author_addresses), "precondition: author_addresses should be schema_locked"

      assert_nothing_raised do
        @connection.disable_referential_integrity { }
      end

      assert schema_locked?(:authors), "authors should be re-locked afterwards"
      assert schema_locked?(:author_addresses), "author_addresses should be re-locked afterwards"
    ensure
      @connection.execute("ALTER TABLE authors SET (schema_locked = false)")
      @connection.execute("ALTER TABLE author_addresses SET (schema_locked = false)")
    end
  end

  private

  def schema_locked?(table)
    reloptions = @connection.query_value(<<~SQL)
      SELECT array_to_string(reloptions, ',') FROM pg_class WHERE relname = #{@connection.quote(table.to_s)}
    SQL
    reloptions.to_s.include?("schema_locked=true")
  end
end
