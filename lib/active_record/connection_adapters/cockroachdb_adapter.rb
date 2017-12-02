require 'active_record/connection_adapters/postgresql_adapter'
require "active_record/connection_adapters/postgresql/schema_statements"
require "active_record/connection_adapters/cockroachdb/schema_statements"
require "active_record/connection_adapters/cockroachdb/referential_integrity"
require "active_record/connection_adapters/cockroachdb/transaction_manager"

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
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:sslmode, :application_name]
      conn_params.slice!(*valid_conn_param_keys)

      # The postgres drivers don't allow the creation of an unconnected
      # PG::Connection object, so just pass a nil connection object for the
      # time being.
      ConnectionAdapters::CockroachDBAdapter.new(nil, logger, conn_params, config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class CockroachDBAdapter < PostgreSQLAdapter
      ADAPTER_NAME = "CockroachDB".freeze

      include CockroachDB::SchemaStatements
      include CockroachDB::ReferentialIntegrity


      # Note that in the migration from ActiveRecord 5.0 to 5.1, the
      # `extract_schema_qualified_name` method was aliased in the PostgreSQLAdapter.
      # To ensure backward compatibility with both <5.1 and 5.1, we rename it here
      # to use the same original `Utils` module.
      Utils = PostgreSQL::Utils

      def supports_json?
        # FIXME(joey): Add a version check.
        true
      end

      def supports_ddl_transactions?
        false
      end

      def supports_extensions?
        false
      end

      def supports_ranges?
        # See cockroachdb/cockroach#17022
        false
      end

      def supports_materialized_views?
        false
      end

      def supports_pg_crypto_uuid?
        false
      end

      def supports_partial_index?
        # See cockroachdb/cockroach#9683
        false
      end

      def supports_expression_index?
        # See cockroachdb/cockroach#9682
        false
      end

      def supports_datetime_with_precision?
        false
      end

      def supports_comments?
        # See cockroachdb/cockroach#19472.
        false
      end

      def supports_comments_in_create?
        # See cockroachdb/cockroach#19472.
        false
      end

      def supports_advisory_locks?
        # FIXME(joey): We may want to make this false.
        true
      end

      def supports_virtual_columns?
        # See cockroachdb/cockroach#20882.
        false
      end

      def supports_savepoints?
        # See cockroachdb/cockroach#10735.
        false
      end

      def transaction_isolation_levels
        {
          # Explicitly prevent READ UNCOMMITTED from being used. This
          # was due to the READ UNCOMMITTED test failing.
          # read_uncommitted: "READ UNCOMMITTED",
          read_committed:   "READ COMMITTED",
          repeatable_read:  "REPEATABLE READ",
          serializable:     "SERIALIZABLE"
        }
      end


      # Sadly, we can only do savepoints at the beginning of
      # transactions. This means that we cannot use them for most cases
      # of transaction, so we just pretend they're usable.
      def create_savepoint(name = "COCKROACH_RESTART"); end

      def exec_rollback_to_savepoint(name = "COCKROACH_RESTART"); end

      def release_savepoint(name = "COCKROACH_RESTART"); end

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
          unique = row[1]
          indkey = row[2].split(" ").map(&:to_i)
          inddef = row[3]
          oid = row[4]
          comment = row[5]

          expressions, where = inddef.scan(/\((.+?)\)(?: WHERE (.+))?\z/).flatten

          if indkey.include?(0)
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

          # FIXME(joey): This may be specific to ActiveRecord 5.2.
          IndexDefinition.new(
            table_name,
            index_name,
            unique,
            columns,
            orders: orders,
            where: where,
            comment: comment.presence
          )
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
      # migration from PostgreSQL to CockroachDB. In practice, this limitation
      # is arbitrary since CockroachDB supports index name lengths and table alias
      # lengths far greater than this value. For the time being though, we match
      # the original behavior for PostgreSQL to simplify migrations.
      #
      # Note that in the migration to ActiveRecord 5.1, this was changed in
      # PostgreSQLAdapter to use `SHOW max_identifier_length` (which does not
      # exist in CockroachDB). Therefore, we have to redefine this here.
      def max_identifier_length
        63
      end
      alias index_name_length max_identifier_length
      alias table_alias_length max_identifier_length

      private

        def initialize_type_map(m = type_map)
          super(m)
          # NOTE(joey): PostgreSQL intervals have a precision.
          # CockroachDB intervals do not, so overide the type
          # definition. Returning a ArgumentError may not be correct.
          # This needs to be tested.
          m.register_type "interval" do |_, _, sql_type|
            precision = extract_precision(sql_type)
            if precision
              raise(ArgumentError, "CockroachDB does not support precision on intervals, but got precision: #{precision}")
            end
            OID::SpecializedString.new(:interval, precision: precision)
          end
        end

        # Configures the encoding, verbosity, schema search path, and time zone of the connection.
        # This is called by #connect and should not be called manually.
        #
        # NOTE(joey): This was cradled from postgresql_adapter.rb. This
        # was due to needing to override configuration statements.
        def configure_connection
          if @config[:encoding]
            @connection.set_client_encoding(@config[:encoding])
          end
          self.client_min_messages = @config[:min_messages] || "warning"
          self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

          # Use standard-conforming strings so we don't have to do the E'...' dance.
          set_standard_conforming_strings

          variables = @config.fetch(:variables, {}).stringify_keys

          # If using Active Record's time zone support configure the connection to return
          # TIMESTAMP WITH ZONE types in UTC.
          unless variables["timezone"]
            if ActiveRecord::Base.default_timezone == :utc
              variables["timezone"] = "UTC"
            elsif @local_tz
              variables["timezone"] = @local_tz
            end
          end

          # NOTE(joey): This is a workaround as CockroachDB 1.1.x
          # supports SET TIME ZONE <...> and SET "time zone" = <...> but
          # not SET timezone = <...>.
          if variables.key?("timezone")
            tz = variables.delete("timezone")
            execute("SET TIME ZONE #{quote(tz)}", "SCHEMA")
          end

          # SET statements from :variables config hash
          # https://www.postgresql.org/docs/current/static/sql-set.html
          variables.map do |k, v|
            if v == ":default" || v == :default
              # Sets the value to the global or compile default

              # NOTE(joey): I am not sure if simply commenting this out
              # is technically correct.
              # execute("SET #{k} = DEFAULT", "SCHEMA")
            elsif !v.nil?
              execute("SET SESSION #{k} = #{quote(v)}", "SCHEMA")
            end
          end
        end


      # end private
    end
  end
end
