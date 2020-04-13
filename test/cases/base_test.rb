require "cases/helper_cockroachdb"

module CockroachDB
  class BasicsTest < ActiveRecord::TestCase
    # This replaces the same test that's been excluded from BasicsTest. It's
    # exactly the same, except badchar has an entry for CockroachDBAdapter.
    def test_column_names_are_escaped
      conn      = ActiveRecord::Base.connection
      classname = conn.class.name[/[^:]*$/]
      badchar   = {
        "SQLite3Adapter"    => '"',
        "Mysql2Adapter"     => "`",
        "PostgreSQLAdapter" => '"',
        "OracleAdapter"     => '"',
        "FbAdapter"         => '"',
        "CockroachDBAdapter" => '"'
      }.fetch(classname) {
        raise "need a bad char for #{classname}"
      }

      quoted = conn.quote_column_name "foo#{badchar}bar"
      if current_adapter?(:OracleAdapter)
        # Oracle does not allow double quotes in table and column names at all
        # therefore quoting removes them
        assert_equal("#{badchar}foobar#{badchar}", quoted)
      else
        assert_equal("#{badchar}foo#{badchar * 2}bar#{badchar}", quoted)
      end
    end
  end
end
