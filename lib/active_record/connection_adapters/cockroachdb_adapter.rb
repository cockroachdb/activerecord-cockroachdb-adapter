require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionHandling
    def cockroachdb_connection(config)
      # This is copied from the PostgreSQL adapter.
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG::Connection.connect.
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      # The postgres drivers don't allow the creation of an unconnected
      # PG::Connection object, so just pass a nil connection object for the
      # time being.
      ConnectionAdapters::CockroachDBAdapter.new(nil, logger, conn_params, config)
    end
  end
end

class ActiveRecord::ConnectionAdapters::CockroachDBAdapter < ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  ADAPTER_NAME = "CockroachDB".freeze

  # Note that in the migration from ActiveRecord 5.0 to 5.1, the
  # `extract_schema_qualified_name` method was aliased in the PostgreSQLAdapter.
  # To ensure backward compatibility with both <5.1 and 5.1, we rename it here
  # to use the same original `Utils` module.
  Utils = ActiveRecord::ConnectionAdapters::PostgreSQL::Utils

  # Savepoints support is currently limited with cockroachdb
  def supports_savepoints?
    false
  end

  # Supporting referential integrity requires TRIGGER support, which is
  # not yet part of cockroach.
  def supports_disable_referential_integrity?
    false
  end

  def supports_json?
      false
  end

  def supports_ddl_transactions?
      false
  end

  def supports_extensions?
      false
  end

  def supports_ranges?
      false
  end

  def supports_materialized_views?
      false
  end

  def supports_pg_crypto_uuid?
      false
  end

  def indexes(table_name, name = nil) # :nodoc:
    # The PostgreSQL adapter uses a correlated subquery in the following query,
    # which CockroachDB does not yet support. That portion of the query fetches
    # any non-standard opclasses that each index uses. CockroachDB also doesn't
    # support opclasses at this time, so the query is modified to just remove
    # the section about opclasses entirely.
    if name
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        Passing name to #indexes is deprecated without replacement.
      MSG
    end

    table = Utils.extract_schema_qualified_name(table_name.to_s)

    result = query(<<-SQL, "SCHEMA")
      SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid), t.oid,
                      pg_catalog.obj_description(i.oid, 'pg_class') AS comment
      FROM pg_class t
      INNER JOIN pg_index d ON t.oid = d.indrelid
      INNER JOIN pg_class i ON d.indexrelid = i.oid
      LEFT JOIN pg_namespace n ON n.oid = i.relnamespace
      WHERE i.relkind = 'i'
        AND d.indisprimary = 'f'
        AND t.relname = '#{table.identifier}'
        AND n.nspname = #{table.schema ? "'#{table.schema}'" : 'ANY (current_schemas(false))'}
      ORDER BY i.relname
    SQL

    result.map do |row|
      index_name = row[0]
      unique = row[1].downcase == "t"
      indkey = row[2].split(" ")
      inddef = row[3]
      oid = row[4]
      comment = row[5]

      expressions, where = inddef.scan(/\((.+?)\)(?: WHERE (.+))?\z/).flatten

      if indkey.include?(0) || indkey.include?("0")
        columns = expressions
      else
        columns = Hash[query(<<-SQL.strip_heredoc, "SCHEMA")].values_at(*indkey).compact
          SELECT a.attnum, a.attname
          FROM pg_attribute a
          WHERE a.attrelid = #{oid}
          AND a.attnum IN (#{indkey.join(",")})
        SQL

        # add info on sort order for columns (only desc order is explicitly specified, asc is the default)
        orders = Hash[
          expressions.scan(/(\w+) DESC/).flatten.map { |order_column| [order_column, :desc] }
        ]
      end

      ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, index_name, unique, columns, [], orders, where, nil, nil)
    end.compact
  end


  def primary_keys(table_name)
      name = Utils.extract_schema_qualified_name(table_name.to_s)
      select_values(<<-SQL.strip_heredoc, "SCHEMA")
      SELECT column_name
          FROM information_schema.key_column_usage kcu
          JOIN information_schema.table_constraints tc
          ON kcu.table_name = tc.table_name
          AND kcu.table_schema = tc.table_schema
          AND kcu.constraint_name = tc.constraint_name
          WHERE constraint_type = 'PRIMARY KEY'
          AND kcu.table_name = #{quote(name.identifier)}
          AND kcu.table_schema = #{name.schema ? quote(name.schema) : "ANY (current_schemas(false))"}
          ORDER BY kcu.ordinal_position
      SQL
  end

  # This is hardcoded to 63 (as previously was in ActiveRecord 5.0) to aid in
  # migration from PostgreSQL to Cockroachdb. In practice, this limitation
  # is arbitrary since CockroachDB supports index name lengths and table alias
  # lengths far greater than this value. For the time being though, we match
  # the original behavior for PostgreSQL to simplify migrations.
  #
  # Note that in the migration to ActiveRecord 5.1, this was changed in
  # PostgreSQLAdapter to use `SHOW max_identifier_length` (which does not
  # exist in CockroachDB). Therefore, we have to redefine this here.
  def table_alias_length
    63
  end
  alias index_name_length table_alias_length
end
