module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements

        def add_index(table_name, column_name, options = {})
          super
        rescue ActiveRecord::StatementInvalid => error
          if debugging? && error.cause.class == PG::FeatureNotSupported
            warn "#{error}\n\nThis error will be ignored and the index will not be created.\n\n"
          else
            raise error
          end
        end

        # ActiveRecord allows for tables to exist without primary keys.
        # Databases like PostgreSQL support this behavior, but CockroachDB does
        # not. If a table is created without a primary key, CockroachDB will add
        # a rowid column to serve as its primary key. This breaks a lot of
        # ActiveRecord's assumptions so we'll treat tables with rowid primary
        # keys as if they didn't have primary keys at all.
        # https://www.cockroachlabs.com/docs/v19.2/create-table.html#create-a-table
        # https://api.rubyonrails.org/v5.2.4/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-create_table
        def primary_key(table_name)
          pk = super

          if pk == CockroachDBAdapter::DEFAULT_PRIMARY_KEY
            nil
          else
            pk
          end
        end

        # CockroachDB uses unique_rowid() for primary keys, not sequences. It's
        # possible to force a table to use sequences, but since it's not the
        # default behavior we'll always return nil for default_sequence_name.
        def default_sequence_name(table_name, pk = "id")
          nil
        end

        def columns(table_name)
          # Limit, precision, and scale are all handled by the superclass.
          column_definitions(table_name).map do |column_name, type, default, notnull, oid, fmod, collation, comment|
            oid = oid.to_i
            fmod = fmod.to_i
            type_metadata = fetch_type_metadata(column_name, type, oid, fmod)
            cast_type = get_oid_type(oid.to_i, fmod.to_i, column_name, type)
            default_value = extract_value_from_default(default)

            default_function = extract_default_function(default_value, default)
            new_column(table_name, column_name, default_value, cast_type, type_metadata, !notnull,
                       default_function, collation, comment)
          end
        end

        def new_column(table_name, column_name, default, cast_type, sql_type_metadata = nil,
                        null = true, default_function = nil, collation = nil, comment = nil)
          # JDBC gets true/false in Rails 4, where other platforms get 't'/'f' strings.
          if null.is_a?(String)
            null = (null == "t")
          end

          column_info = spatial_column_info(table_name).get(column_name, sql_type_metadata.sql_type)

          PostgreSQLColumn.new(
            column_name,
            default,
            sql_type_metadata,
            null,
            table_name,
            default_function,
            collation,
            comment,
            cast_type,
            column_info
          )
        end

        # CockroachDB will use INT8 if the SQL type is INTEGER, so we make it use
        # INT4 explicitly when needed.
        #
        # For spatial columns, include the limit to properly format the column name
        # since type alone is not enough to format the column.
        # Ex. type_to_sql(:geography, limit: "Point,4326")
        # => "geography(Point,4326)"
        # 
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, array: nil, **) # :nodoc:
          sql = \
            case type.to_s
            when "integer"
              case limit
              when nil; "int"
              when 1, 2; "int2"
              when 3, 4; "int4"
              when 5..8; "int8"
              else super
              end
            when "geometry", "geography"
              "#{type}(#{limit})"
            else
              super
            end
          # The call to super might have appeneded [] already.
          if array && type != :primary_key && !sql.end_with?("[]")
            sql = "#{sql}[]" 
          end
          sql
        end

        # override
        def native_database_types
          # Add spatial types
          super.merge(
            geography:           { name: "geography" },
            geometry:            { name: "geometry" },
            geometry_collection: { name: "geometry_collection" },
            line_string:         { name: "line_string" },
            multi_line_string:   { name: "multi_line_string" },
            multi_point:         { name: "multi_point" },
            multi_polygon:       { name: "multi_polygon" },
            spatial:             { name: "geometry" },
            st_point:            { name: "st_point" },
            st_polygon:          { name: "st_polygon" }
          )
        end

        # override
        def create_table_definition(*args, **kwargs)
          CockroachDB::TableDefinition.new(*args, **kwargs)
        end

        # memoize hash of column infos for tables
        def spatial_column_info(table_name)
          @spatial_column_info ||= {}
          @spatial_column_info[table_name.to_sym] ||= SpatialColumnInfo.new(self, table_name.to_s)
        end
      end
    end
  end
end
