# frozen_string_literal: true

require "rgeo/active_record"

require_relative "../../arel/nodes/join_source_ext"
require "active_record/connection_adapters/postgresql_adapter"
require "active_record/connection_adapters/cockroachdb/attribute_methods"
require "active_record/connection_adapters/cockroachdb/column_methods"
require "active_record/connection_adapters/cockroachdb/schema_creation"
require "active_record/connection_adapters/cockroachdb/schema_dumper"
require "active_record/connection_adapters/cockroachdb/schema_statements"
require "active_record/connection_adapters/cockroachdb/referential_integrity"
require "active_record/connection_adapters/cockroachdb/transaction_manager"
require "active_record/connection_adapters/cockroachdb/database_statements"
require "active_record/connection_adapters/cockroachdb/table_definition"
require "active_record/connection_adapters/cockroachdb/quoting"
require "active_record/connection_adapters/cockroachdb/type"
require "active_record/connection_adapters/cockroachdb/column"
require "active_record/connection_adapters/cockroachdb/spatial_column_info"
require "active_record/connection_adapters/cockroachdb/setup"
require "active_record/connection_adapters/cockroachdb/oid/spatial"
require "active_record/connection_adapters/cockroachdb/oid/interval"
require "active_record/connection_adapters/cockroachdb/oid/date_time"
require "active_record/connection_adapters/cockroachdb/arel_tosql"
require_relative "../migration/cockroachdb/compatibility"
require_relative "../../version"

require_relative "../relation/query_methods_ext"

# Run to ignore spatial tables that will break schemna dumper.
# Defined in ./setup.rb
ActiveRecord::ConnectionAdapters::CockroachDB.initial_setup

module ActiveRecord
  module ConnectionHandling
    def cockroachdb_connection(config)
      # This is copied from the PostgreSQL adapter.
      conn_params = config.symbolize_keys.compact

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PG::Connection.connect.
      valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
      conn_params.slice!(*valid_conn_param_keys)

      ConnectionAdapters::CockroachDBAdapter.new(
        ConnectionAdapters::CockroachDBAdapter.new_client(conn_params),
        logger,
        conn_params,
        config
      )
    # This rescue flow appears in new_client, but it is needed here as well
    # since Cockroach will sometimes not raise until a query is made.
    rescue ActiveRecord::StatementInvalid => error
      no_db_err_check1 = conn_params && conn_params[:dbname] && error.cause.message.include?(conn_params[:dbname])
      no_db_err_check2 = conn_params && conn_params[:dbname] && error.cause.message.include?("pg_type")
      if no_db_err_check1 || no_db_err_check2
        raise ActiveRecord::NoDatabaseError
      else
        raise ActiveRecord::ConnectionNotEstablished, error.message
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    module CockroachDBConnectionPool
      def initialize(pool_config)
        super(pool_config)
        disable_telemetry = pool_config.db_config.configuration_hash[:disable_cockroachdb_telemetry]
        adapter = pool_config.db_config.configuration_hash[:adapter]
        return if disable_telemetry || adapter != "cockroachdb"

        begin
          with_connection do |conn|
            if conn.active?
              begin
                ar_version = conn.quote("ActiveRecord %d.%d" % [ActiveRecord::VERSION::MAJOR,
                                                                ActiveRecord::VERSION::MINOR])
                ar_query = "SELECT crdb_internal.increment_feature_counter(%s)" % ar_version
                adapter_version = conn.quote("activerecord-cockroachdb-adapter #{ActiveRecord::COCKROACH_DB_ADAPTER_VERSION}")
                adapter_query = "SELECT crdb_internal.increment_feature_counter(%s)" % adapter_version

                conn.execute(ar_query)
                conn.execute(adapter_query)
              rescue ActiveRecord::StatementInvalid
                # The increment_feature_counter built-in is not supported on this
                # CockroachDB version. Ignore.
              rescue StandardError => e
                conn.logger.warn "Unexpected error when incrementing feature counter: #{e}"
              end
            end
          end
        rescue StandardError
          # Prevent failures on db creation and parallel testing.
        end
      end
    end
    ConnectionPool.prepend(CockroachDBConnectionPool)

    class CockroachDBAdapter < PostgreSQLAdapter
      ADAPTER_NAME = "CockroachDB"
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

      def get_database_version
        major, minor, patch = query_value("SHOW crdb_version").match(/v(\d+).(\d+).(\d+)/)[1..].map(&:to_i)
        major * 100 * 100 + minor * 100 + patch
      end
      undef :postgresql_version
      alias :cockroachdb_version :database_version

      def supports_datetime_with_precision?
        # https://github.com/cockroachdb/cockroach/pull/111400
        database_version >= 23_01_13
      end

      def supports_nulls_not_distinct?
        # https://github.com/cockroachdb/cockroach/issues/115836
        false
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

      def supports_index_include?
        false
      end

      def supports_exclusion_constraints?
        false
      end

      def supports_expression_index?
        # Expression indexes are partially supported by CockroachDB v21.2,
        # but activerecord requires "ON CONFLICT expression" support.
        # See https://github.com/cockroachdb/cockroach/issues/67893
        false
      end

      def supports_comments_in_create?
        false
      end

      def supports_advisory_locks?
        false
      end

      def supports_virtual_columns?
        true
      end

      def supports_string_to_array_coercion?
        true
      end

      def supports_partitioned_indexes?
        false
      end

      def supports_deferrable_constraints?
        false
      end

      # NOTE: This commented bit of code allows to have access to crdb version,
      # which can be useful for feature detection. However, we currently don't
      # need, hence we avoid the extra queries.
      #
      #   def initialize(connection, logger, conn_params, config)
      #     super(connection, logger, conn_params, config)

      #     # crdb_version is the version of the binary running on the node. We
      #     # really want to use `SHOW CLUSTER SETTING version` to get the cluster
      #     # version, but that is only available to admins. Instead, we can use
      #     # crdb_internal.is_at_least_version, but that's only available in 22.1.
      #     crdb_version_string = query_value("SHOW crdb_version")
      #     if crdb_version_string.include? "v22.1"
      #       version_num = query_value(<<~SQL, "VERSION")
      #         SELECT
      #           CASE
      #           WHEN crdb_internal.is_at_least_version('22.2') THEN 2220
      #           WHEN crdb_internal.is_at_least_version('22.1') THEN 2210
      #           ELSE 2120
      #           END;
      #       SQL
      #     end
      #     @crdb_version = version_num.to_i
      #   end

      def self.database_exists?(config)
        !!ActiveRecord::Base.cockroachdb_connection(config)
      rescue ActiveRecord::NoDatabaseError
        false
      end

      # override
      # The PostgreSQLAdapter uses syntax for an anonymous function
      # (DO $$) that CockroachDB does not support.
      #
      # Given a name and an array of values, creates an enum type.
      def create_enum(name, values, **options)
        sql_values = values.map { |s| quote(s) }.join(", ")
        query = <<~SQL
          CREATE TYPE IF NOT EXISTS #{quote_table_name(name)} AS ENUM (#{sql_values});
        SQL
        internal_exec_query(query).tap { reload_type_map }
      end

      class << self
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

          # Belongs after other types are defined because of issues described
          # in this https://github.com/rails/rails/pull/38571
          # Once that PR is merged, we can call super at the top.
          super(m)

          # Override numeric type. This is almost identical to the default,
          # except that the conditional based on the fmod is changed.
          m.register_type "numeric" do |_, fmod, sql_type|
            precision = extract_precision(sql_type)
            scale = extract_scale(sql_type)


            # The type for the numeric depends on the width of the field,
            # so we'll do something special here.
            #
            # When dealing with decimal columns:
            #
            # places after decimal  = fmod - 4 & 0xffff
            # places before decimal = (fmod - 4) >> 16 & 0xffff
            #
            # For older versions of CockroachDB (<v22.1), fmod is -1 for 0 width.
            # If fmod is -1, that means that precision is defined but not
            # scale, or neither is defined.
            if fmod && ((fmod == -1 && !precision.nil?) || (fmod - 4 & 0xffff).zero?)
              # Below comment is from ActiveRecord
              # FIXME: Remove this class, and the second argument to
              # lookups on PG
              Type::DecimalWithoutScale.new(precision: precision)
            else
              ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Decimal.new(precision: precision, scale: scale)
            end
          end
        end
      end

      private

        # Override extract_value_from_default because the upstream definition
        # doesn't handle the variations in CockroachDB's behavior.
        def extract_value_from_default(default)
          super ||
            extract_escaped_string_from_default(default) ||
            extract_empty_array_from_default(default) ||
            extract_decimal_from_default(default)
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

        # CockroachDB stores default values for arrays in the `ARRAY[...]` format.
        # In general, it is hard to parse that, but it is easy to handle the common
        # case of an empty array.
        def extract_empty_array_from_default(default)
          return unless supports_string_to_array_coercion?
          return unless default =~ /\AARRAY\[\]\z/
          return "{}"
        end

        # This method exists to extract the decimal defaults (e.g. scientific notation)
        # that don't get parsed correctly
        def extract_decimal_from_default(default)
          Float(default).to_s
        rescue
          nil
        end

        # override
        # This method makes a query to gather information about columns
        # in a table. It returns an array of arrays (one for each col) and
        # passes each to the SchemaStatements#new_column_from_field method
        # as the field parameter. This data is then used to format the column
        # objects for the model and sent to the OID for data casting.
        #
        # Sometimes there are differences between how data is formatted
        # in Postgres and CockroachDB, so additional queries for certain types
        # may be necessary to properly form the column definition.
        #
        # @see: https://github.com/rails/rails/blob/8695b028261bdd244e254993255c6641bdbc17a5/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L829
        def column_definitions(table_name)
          fields = query(<<~SQL, "SCHEMA")
              SELECT a.attname, format_type(a.atttypid, a.atttypmod),
                     pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
                     c.collname, NULL AS comment,
                     attidentity,
                     attgenerated,
                     NULL as is_hidden
                FROM pg_attribute a
                LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                LEFT JOIN pg_type t ON a.atttypid = t.oid
                LEFT JOIN pg_collation c ON a.attcollation = c.oid AND a.attcollation <> t.typcollation
               WHERE a.attrelid = #{quote(quote_table_name(table_name))}::regclass
                 AND a.attnum > 0 AND NOT a.attisdropped
               ORDER BY a.attnum
          SQL

          crdb_fields = crdb_column_definitions(table_name)

          # Use regex comparison because if a type is an array it will
          # have [] appended to the end of it.
          re = /\A(?:geometry|geography|interval|numeric)/

          # 0: attname
          # 1: type
          # 2: default
          # 3: attnotnull
          # 4: atttypid
          # 5: atttypmod
          # 6: collname
          # 7: comment
          # 8: attidentity
          # 9: attgenerated
          # 10: is_hidden
          fields.map do |field|
            dtype = field[1]
            field[1] = crdb_fields[field[0]][2].downcase if re.match(dtype)
            field[7] = crdb_fields[field[0]][1]&.gsub!(/^\'|\'?$/, '')
            field[10] = true if crdb_fields[field[0]][3]
            field
          end
          fields.delete_if do |field|
            # Don't include rowid column if it is hidden and the primary key
            # is not defined (meaning CRDB implicitly created it).
            if field[0] == CockroachDBAdapter::DEFAULT_PRIMARY_KEY
              field[10] && !primary_key(table_name)
            else
              false # Keep this entry.
            end
          end
        end

        # Fetch the column comment because it's faster this way
        # Use the crdb_sql_type instead of the sql_type returned by
        # column_definitions. This will include limit,
        # precision, and scale information in the type.
        # Ex. geometry -> geometry(point, 4326)
        def crdb_column_definitions(table_name)
          table_name = PostgreSQL::Utils.extract_schema_qualified_name(table_name)
          table = table_name.identifier
          with_schema = " AND c.table_schema = #{quote(table_name.schema)}" if table_name.schema
          fields = \
          query(<<~SQL, "SCHEMA")
            SELECT c.column_name, c.column_comment, c.crdb_sql_type, c.is_hidden::BOOLEAN
            FROM information_schema.columns c
            WHERE c.table_name = #{quote(table)}#{with_schema}
          SQL

          fields.reduce({}) do |a, e|
            a[e[0]] = e
            a
          end
        end

        # override
        # This method is used to determine if a
        # FEATURE_NOT_SUPPORTED error from the PG gem should
        # be an ActiveRecord::PreparedStatementCacheExpired
        # error.
        #
        # ActiveRecord handles this by checking that the sql state matches the
        # FEATURE_NOT_SUPPORTED code and that the source function
        # is "RevalidateCachedQuery" since that is the only function
        # in postgres that will create this error.
        #
        # That method will not work for CockroachDB because the error
        # originates from the "runExecBuilder" function, so we need
        # to modify the original to match the CockroachDB behavior.
        def is_cached_plan_failure?(e)
          pgerror = e.cause

          pgerror.result.result_error_field(PG::PG_DIAG_SQLSTATE) == FEATURE_NOT_SUPPORTED &&
            pgerror.result.result_error_field(PG::PG_DIAG_SOURCE_FUNCTION) == "runExecBuilder"
        rescue
          false
        end

        # override
        # This method loads info about data types from the database to
        # populate the TypeMap.
        #
        # Currently, querying from the pg_type catalog can be slow due to geo-partitioning
        # so this modified query uses AS OF SYSTEM TIME '-10s' to read historical data.
        def load_additional_types(oids = nil)
          if @config[:use_follower_reads_for_type_introspection]
            initializer = OID::TypeMapInitializer.new(type_map)
            load_types_queries_with_aost(initializer, oids) do |query|
              execute_and_clear(query, "SCHEMA", [], allow_retry: true, materialize_transactions: false) do |records|
                initializer.run(records)
              end
            end
          else
            super
          end
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.cause.is_a? PG::InvalidCatalogName
          # use original if database is younger than 10s
          super
        end

        def load_types_queries_with_aost(initializer, oids)
          query = <<~SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
            FROM pg_type as t
            LEFT JOIN pg_range as r ON oid = rngtypid AS OF SYSTEM TIME '-10s'
          SQL
          if oids
            yield query + "WHERE t.oid IN (%s)" % oids.join(", ")
          else
            yield query + initializer.query_conditions_for_known_type_names
            yield query + initializer.query_conditions_for_known_type_types
            yield query + initializer.query_conditions_for_array_types
          end
        end

        # override
        # This method maps data types to their proper decoder.
        #
        # Currently, querying from the pg_type catalog can be slow due to geo-partitioning
        # so this modified query uses AS OF SYSTEM TIME '-10s' to read historical data.
        def add_pg_decoders
          if @config[:use_follower_reads_for_type_introspection]
            @default_timezone = nil
            @timestamp_decoder = nil

            coders_by_name = {
              "int2" => PG::TextDecoder::Integer,
              "int4" => PG::TextDecoder::Integer,
              "int8" => PG::TextDecoder::Integer,
              "oid" => PG::TextDecoder::Integer,
              "float4" => PG::TextDecoder::Float,
              "float8" => PG::TextDecoder::Float,
              "numeric" => PG::TextDecoder::Numeric,
              "bool" => PG::TextDecoder::Boolean,
              "timestamp" => PG::TextDecoder::TimestampUtc,
              "timestamptz" => PG::TextDecoder::TimestampWithTimeZone,
            }

            known_coder_types = coders_by_name.keys.map { |n| quote(n) }
            query = <<~SQL % known_coder_types.join(", ")
              SELECT t.oid, t.typname
              FROM pg_type as t AS OF SYSTEM TIME '-10s'
              WHERE t.typname IN (%s)
            SQL

            coders = execute_and_clear(query, "SCHEMA", [], allow_retry: true, materialize_transactions: false) do |result|
              result.filter_map { |row| construct_coder(row, coders_by_name[row["typname"]]) }
            end

            map = PG::TypeMapByOid.new
            coders.each { |coder| map.add_coder(coder) }
            @raw_connection.type_map_for_results = map

            @type_map_for_results = PG::TypeMapByOid.new
            @type_map_for_results.default_type_map = map
            @type_map_for_results.add_coder(PG::TextDecoder::Bytea.new(oid: 17, name: "bytea"))
            @type_map_for_results.add_coder(MoneyDecoder.new(oid: 790, name: "money"))

            # extract timestamp decoder for use in update_typemap_for_default_timezone
            @timestamp_decoder = coders.find { |coder| coder.name == "timestamp" }
            update_typemap_for_default_timezone
          else
            super
          end
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.cause.is_a? PG::InvalidCatalogName
          # use original if database is younger than 10s
          super
        end

        def arel_visitor
          Arel::Visitors::CockroachDB.new(self)
        end

      # end private
    end
  end
end
