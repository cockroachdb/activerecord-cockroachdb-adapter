require 'active_record/connection_adapters/postgresql_adapter'
require "active_record/connection_adapters/cockroachdb/schema_statements"
require "active_record/connection_adapters/cockroachdb/referential_integrity"
require "active_record/connection_adapters/cockroachdb/transaction_manager"
require "active_record/connection_adapters/cockroachdb/column"
require "active_record/connection_adapters/cockroachdb/database_statements"
require "active_record/connection_adapters/cockroachdb/quoting"
require "active_record/connection_adapters/cockroachdb/type"
require "active_record/connection_adapters/cockroachdb/attribute_methods"

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
      DEFAULT_PRIMARY_KEY = "rowid"

      include CockroachDB::SchemaStatements
      include CockroachDB::ReferentialIntegrity
      include CockroachDB::DatabaseStatements
      include CockroachDB::Quoting

      def debugging?
        !!ENV["DEBUG_COCKROACHDB_ADAPTER"]
      end

      def max_transaction_retries
        @max_transaction_retries ||= @config.fetch(:max_transaction_retries, 3)
      end

      # CockroachDB 20.1 can run queries that work against PostgreSQL 10+.
      def postgresql_version
        100000
      end

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
        false
      end

      def supports_virtual_columns?
        # See cockroachdb/cockroach#20882.
        false
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

        # Override extract_value_from_default because the upstream definition
        # doesn't handle the variations in CockroachDB's behavior.
        def extract_value_from_default(default)
          super ||
            extract_escaped_string_from_default(default) ||
            extract_time_from_default(default)
        end

        # Both PostgreSQL and CockroachDB use C-style string escapes under the
        # covers. PostgreSQL obscures this for us and unescapes the strings, but
        # CockroachDB does not. Here we'll use Ruby to unescape the string.
        # See https://github.com/cockroachdb/cockroach/issues/47497 and
        # https://www.postgresql.org/docs/9.2/sql-syntax-lexical.html#SQL-SYNTAX-STRINGS-ESCAPE.
        def extract_escaped_string_from_default(default)
          # Escaped strings start with an e followed by the string in quotes (e'…')
          return unless default =~ /\A[\(B]?e'(.*)'.*::"?([\w. ]+)"?(?:\[\])?\z/m

          # String#undump doesn't account for escaped single quote characters
          "\"#{$1}\"".undump.gsub("\\'".freeze, "'".freeze)
        end

        # This method exists to extract the correct time and date defaults for a
        # couple of reasons.
        # 1) There's a bug in CockroachDB where the date type is missing from
        # the column info query.
        # https://github.com/cockroachdb/cockroach/issues/47285
        # 2) PostgreSQL's timestamp without time zone type maps to CockroachDB's
        # TIMESTAMP type. TIMESTAMP includes a UTC time zone while timestamp
        # without time zone doesn't.
        # https://www.cockroachlabs.com/docs/v19.2/timestamp.html#variants
        def extract_time_from_default(default)
          return unless default =~ /\A'(.*)'\z/

          # If default has a UTC time zone, we'll drop the time zone information
          # so it acts like PostgreSQL's timestamp without time zone. Then, try
          # to parse the resulting string to verify if it's a time.
          time = if default =~ /\A'(.*)(\+00:00)'\z/
            $1
          else
            default
          end

          Time.parse(time).to_s
        rescue
          nil
        end

      # end private
    end
  end
end
