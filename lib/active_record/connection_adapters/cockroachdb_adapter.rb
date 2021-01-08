require "rgeo/active_record"

require 'active_record/connection_adapters/postgresql_adapter'
require "active_record/connection_adapters/cockroachdb/column_methods"
require "active_record/connection_adapters/cockroachdb/schema_statements"
require "active_record/connection_adapters/cockroachdb/referential_integrity"
require "active_record/connection_adapters/cockroachdb/transaction_manager"
require "active_record/connection_adapters/cockroachdb/database_statements"
require "active_record/connection_adapters/cockroachdb/table_definition"
require "active_record/connection_adapters/cockroachdb/quoting"
require "active_record/connection_adapters/cockroachdb/type"
require "active_record/connection_adapters/cockroachdb/attribute_methods"
require "active_record/connection_adapters/cockroachdb/column"
require "active_record/connection_adapters/cockroachdb/spatial_column_info"
require "active_record/connection_adapters/cockroachdb/setup"
require "active_record/connection_adapters/cockroachdb/oid/spatial"
require "active_record/connection_adapters/cockroachdb/arel_tosql"

# Run to ignore spatial tables that will break schemna dumper.
# Defined in ./setup.rb
ActiveRecord::ConnectionAdapters::CockroachDB.initial_setup

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

      conn = PG.connect(conn_params)
      ConnectionAdapters::CockroachDBAdapter.new(conn, logger, conn_params, config)
    rescue ::PG::Error, ActiveRecord::ActiveRecordError  => error
      if error.message.include?("does not exist")
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class CockroachDBAdapter < PostgreSQLAdapter
      ADAPTER_NAME = "CockroachDB".freeze
      DEFAULT_PRIMARY_KEY = "rowid"

      SPATIAL_COLUMN_OPTIONS =
        {
          geography:           { geographic: true },
          geometry:            {},
          geometry_collection: {},
          line_string:         {},
          multi_line_string:   {},
          multi_point:         {},
          multi_polygon:       {},
          spatial:             {},
          st_point:            {},
          st_polygon:          {},
        }

      # http://postgis.17.x6.nabble.com/Default-SRID-td5001115.html      
      DEFAULT_SRID = 0

      include CockroachDB::SchemaStatements
      include CockroachDB::ReferentialIntegrity
      include CockroachDB::DatabaseStatements
      include CockroachDB::Quoting

      # override
      # This method makes a sql query to gather information about columns
      # in a table. It returns an array of arrays (one for each col) and
      # passes each to the SchemaStatements#new_column_from_field method
      # as the field parameter. This data is then used to format the column
      # objects for the model and sent to the OID for data casting.
      #
      # The issue with the default method is that the sql_type field is 
      # retrieved with the `format_type` function, but this is implemented
      # differently in CockroachDB than PostGIS, so geometry/geography
      # types are missing information which makes parsing them impossible.
      # Below is an example of what `format_type` returns for a geometry
      # column.
      #
      # column_type: geometry(POINT, 4326)
      # Expected: geometry(POINT, 4326)
      # Actual: geometry
      #
      # The solution is to make the default query with super, then
      # iterate through the columns and if it is a spatial type,
      # access the proper column_type with the information_schema.columns 
      # table.
      #
      # @see: https://github.com/rails/rails/blob/8695b028261bdd244e254993255c6641bdbc17a5/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L829
      def column_definitions(table_name)
        fields = super
        # iterate through and identify all spatial fields based on format_type
        # being geometry or geography, then query for the information_schema.column
        # column_type because that contains the necessary information.
        fields.map do |field|
          dtype = field[1]
          if dtype == 'geometry' || dtype == 'geography'
            col_name = field[0]
            data_type = \
            query(<<~SQL, "SCHEMA")
              SELECT c.data_type
                FROM information_schema.columns c
              WHERE c.table_name = #{quote(table_name)}
                AND c.column_name = #{quote(col_name)}
            SQL
            field[1] = data_type[0][0]
          end
          field
        end
      end

      def arel_visitor
        Arel::Visitors::CockroachDB.new(self)
      end

      def self.spatial_column_options(key)
        SPATIAL_COLUMN_OPTIONS[key]
      end

      def postgis_lib_version
        @postgis_lib_version ||= select_value("SELECT PostGIS_Lib_Version()")
      end

      def default_srid
        DEFAULT_SRID
      end

      def srs_database_columns
        {
          auth_name_column: "auth_name",
          auth_srid_column: "auth_srid",
          proj4text_column: "proj4text",
          srtext_column:    "srtext",
        }
      end

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

      def supports_bulk_alter?
        false
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

      def supports_materialized_views?
        false
      end

      def supports_partial_index?
        @crdb_version >= 202
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

      def supports_string_to_array_coercion?
        @crdb_version >= 202
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

      def initialize(connection, logger, conn_params, config)
        super(connection, logger, conn_params, config)
        crdb_version_string = query_value("SHOW crdb_version")
        if crdb_version_string.include? "v1."
          version_num = 1
        elsif crdb_version_string.include? "v2."
          version_num 2
        elsif crdb_version_string.include? "v19.1."
          version_num = 191
        elsif crdb_version_string.include? "v19.2."
          version_num = 192
        elsif crdb_version_string.include? "v20.1."
          version_num = 201
        else
          version_num = 202
        end
        @crdb_version = version_num
      end

      def self.database_exists?(config)
        !!ActiveRecord::Base.cockroachdb_connection(config)
      rescue ActiveRecord::NoDatabaseError
        false
      end

      private

        def initialize_type_map(m = type_map)
          %w(
            geography
            geometry
            geometry_collection
            line_string
            multi_line_string
            multi_point
            multi_polygon
            st_point
            st_polygon
          ).each do |geo_type|
            m.register_type(geo_type) do |oid, _, sql_type|
              CockroachDB::OID::Spatial.new(oid, sql_type)
            end
          end

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

          super(m)
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
            extract_time_from_default(default) ||
            extract_empty_array_from_default(default)
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

        # CockroachDB stores default values for arrays in the `ARRAY[...]` format.
        # In general, it is hard to parse that, but it is easy to handle the common
        # case of an empty array.
        def extract_empty_array_from_default(default)
          return unless supports_string_to_array_coercion? 
          return unless default =~ /\AARRAY\[\]\z/
          return "{}"
        end

      # end private
    end
  end
end
