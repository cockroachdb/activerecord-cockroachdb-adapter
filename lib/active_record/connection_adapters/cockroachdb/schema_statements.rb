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

        # override
        # https://github.com/rails/rails/blob/6-0-stable/activerecord/lib/active_record/connection_adapters/postgresql/schema_statements.rb#L624
        def new_column_from_field(table_name, field)
          column_name, type, default, notnull, oid, fmod, collation, comment = field
          type_metadata = fetch_type_metadata(column_name, type, oid.to_i, fmod.to_i)
          default_value = extract_value_from_default(default)
          default_function = extract_default_function(default_value, default)

          serial =
            if (match = default_function&.match(/\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z/))
              sequence_name_from_parts(table_name, column_name, match[:suffix]) == match[:sequence_name]
            end

          # {:dimension=>2, :has_m=>false, :has_z=>false, :name=>"latlon", :srid=>0, :type=>"GEOMETRY"}
          spatial = spatial_column_info(table_name).get(column_name, type_metadata.sql_type)

          PostgreSQL::Column.new(
            column_name,
            default_value,
            type_metadata,
            !notnull,
            default_function,
            collation: collation,
            comment: comment.presence,
            serial: serial,
            spatial: spatial
          )
        end

        # copied from ConnectionAdapters::SchemaStatements
        #
        # modified insert into statement to always wrap the version value into single quotes for cockroachdb.
        def assume_migrated_upto_version(version, migrations_paths = nil)
          unless migrations_paths.nil?
            ActiveSupport::Deprecation.warn(<<~MSG.squish)
            Passing migrations_paths to #assume_migrated_upto_version is deprecated and will be removed in Rails 6.1.
            MSG
          end

          version = version.to_i
          sm_table = quote_table_name(schema_migration.table_name)

          migrated = migration_context.get_all_versions
          versions = migration_context.migrations.map(&:version)

          unless migrated.include?(version)
            execute "INSERT INTO #{sm_table} (version) VALUES ('#{quote(version)}')"
          end

          inserting = (versions - migrated).select { |v| v < version }
          if inserting.any?
            if (duplicate = inserting.detect { |v| inserting.count(v) > 1 })
              raise "Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict."
            end
            execute insert_versions_sql(inserting)
          end
        end

        # copied from ConnectionAdapters::SchemaStatements
        #
        # modified insert into statement to always wrap the version value into single quotes for cockroachdb.
        def insert_versions_sql(versions)
          sm_table = quote_table_name(schema_migration.table_name)

          if versions.is_a?(Array)
            sql = +"INSERT INTO #{sm_table} (version) VALUES\n"
            sql << versions.map { |v| "('#{quote(v)}')" }.join(",\n")
            sql << ";\n\n"
            sql
          else
            "INSERT INTO #{sm_table} (version) VALUES ('#{quote(versions)}');"
          end
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

        # This overrides the method from PostegreSQL adapter
        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil)
          unless pk && sequence
            default_pk, default_sequence = pk_and_sequence_for(table)

            pk ||= default_pk
            sequence ||= default_sequence
          end

          if @logger && pk && !sequence
            @logger.warn "#{table} has primary key #{pk} with no default sequence."
          end

          if pk && sequence
            quoted_sequence = quote_table_name(sequence)
            max_pk = query_value("SELECT MAX(#{quote_column_name pk}) FROM #{quote_table_name(table)}", "SCHEMA")
            if max_pk.nil?
              minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
            end

            query_value("SELECT setval(#{quote(quoted_sequence)}, #{max_pk ? max_pk : minvalue}, #{max_pk ? true : false})", "SCHEMA")
          end
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
          CockroachDB::TableDefinition.new(self, *args, **kwargs)
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
