module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements

        def add_index(table_name, column_name, **options)
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

        def primary_keys(table_name)
          return super unless database_version >= 24_02_02

          query_values(<<~SQL, "SCHEMA")
            SELECT a.attname
              FROM (
                     SELECT indrelid, indkey, generate_subscripts(indkey, 1) idx
                       FROM pg_index
                      WHERE indrelid = #{quote(quote_table_name(table_name))}::regclass
                        AND indisprimary
                   ) i
              JOIN pg_attribute a
                ON a.attrelid = i.indrelid
               AND a.attnum = i.indkey[i.idx]
               AND NOT a.attishidden
             ORDER BY i.idx
          SQL
        end

        def column_names_from_column_numbers(table_oid, column_numbers)
          return super unless database_version >= 24_02_02

          Hash[query(<<~SQL, "SCHEMA")].values_at(*column_numbers).compact
            SELECT a.attnum, a.attname
            FROM pg_attribute a
            WHERE a.attrelid = #{table_oid}
            AND a.attnum IN (#{column_numbers.join(", ")})
            AND NOT a.attishidden
          SQL
        end

        # OVERRIDE: CockroachDB does not support deferrable constraints.
        #   See: https://go.crdb.dev/issue-v/31632/v23.1
        def foreign_key_options(from_table, to_table, options)
          options = super
          options.delete(:deferrable) unless supports_deferrable_constraints?
          options
        end

        # OVERRIDE: Added `unique_rowid` to the last line of the second query.
        #   This is a CockroachDB-specific function used for primary keys.
        #   Also make sure we don't consider `NOT VISIBLE` columns.
        #
        # Returns a table's primary key and belonging sequence.
        def pk_and_sequence_for(table) # :nodoc:
          # First try looking for a sequence with a dependency on the
          # given table's primary key.
          result = query(<<~SQL, "SCHEMA")[0]
            SELECT attr.attname, nsp.nspname, seq.relname
            FROM pg_class      seq,
                 pg_attribute  attr,
                 pg_depend     dep,
                 pg_constraint cons,
                 pg_namespace  nsp,
                 -- TODO: use the pg_catalog.pg_attribute(attishidden) column when
                 --   it is added instead of joining on crdb_internal.
                 --   See https://github.com/cockroachdb/cockroach/pull/126397
                 crdb_internal.table_columns tc
            WHERE seq.oid           = dep.objid
              AND seq.relkind       = 'S'
              AND attr.attrelid     = dep.refobjid
              AND attr.attnum       = dep.refobjsubid
              AND attr.attrelid     = cons.conrelid
              AND attr.attnum       = cons.conkey[1]
              AND seq.relnamespace  = nsp.oid
              AND attr.attrelid     = tc.descriptor_id
              AND attr.attname      = tc.column_name
              AND tc.hidden         = false
              AND cons.contype      = 'p'
              AND dep.classid       = 'pg_class'::regclass
              AND dep.refobjid      = #{quote(quote_table_name(table))}::regclass
          SQL

          if result.nil? || result.empty?
            result = query(<<~SQL, "SCHEMA")[0]
              SELECT attr.attname, nsp.nspname,
                CASE
                  WHEN pg_get_expr(def.adbin, def.adrelid) !~* 'nextval' THEN NULL
                  WHEN split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2) ~ '.' THEN
                    substr(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2),
                           strpos(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2), '.')+1)
                  ELSE split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2)
                END
              FROM pg_class       t
              JOIN pg_attribute   attr ON (t.oid = attrelid)
              JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
              JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
              JOIN pg_namespace   nsp  ON (t.relnamespace = nsp.oid)
              -- TODO: use the pg_catalog.pg_attribute(attishidden) column when
              --   it is added instead of joining on crdb_internal.
              --   See https://github.com/cockroachdb/cockroach/pull/126397
              JOIN crdb_internal.table_columns tc ON (attr.attrelid = tc.descriptor_id AND attr.attname = tc.column_name)
              WHERE t.oid = #{quote(quote_table_name(table))}::regclass
                AND tc.hidden = false
                AND cons.contype = 'p'
                AND pg_get_expr(def.adbin, def.adrelid) ~* 'nextval|uuid_generate|gen_random_uuid|unique_rowid'
            SQL
          end

          pk = result.shift
          if result.last
            [pk, PostgreSQL::Name.new(*result)]
          else
            [pk, nil]
          end
        rescue
          nil
        end

        # override
        # Modified version of the postgresql foreign_keys method.
        # Replaces t2.oid::regclass::text with t2.relname since this is
        # more efficient in CockroachDB.
        def foreign_keys(table_name)
          scope = quoted_scope(table_name)
          fk_info = exec_query(<<~SQL, "SCHEMA")
            SELECT t2.relname AS to_table, a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{scope[:name]}
              AND t3.nspname = #{scope[:schema]}
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            options = {
              column: row["column"],
              name: row["name"],
              primary_key: row["primary_key"]
            }

            options[:on_delete] = extract_foreign_key_action(row["on_delete"])
            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:validate] = row["valid"]

            ForeignKeyDefinition.new(table_name, row["to_table"], options)
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
          column_name, type, default, notnull, oid, fmod, collation, comment, generated, hidden = field
          type_metadata = fetch_type_metadata(column_name, type, oid.to_i, fmod.to_i)
          default_value = extract_value_from_default(default)
          default_function = extract_default_function(default_value, default)

          serial =
            if (match = default_function&.match(/\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z/))
              sequence_name_from_parts(table_name, column_name, match[:suffix]) == match[:sequence_name]
            end

          # {:dimension=>2, :has_m=>false, :has_z=>false, :name=>"latlon", :srid=>0, :type=>"GEOMETRY"}
          spatial = spatial_column_info(table_name).get(column_name, type_metadata.sql_type)

          CockroachDB::Column.new(
            column_name,
            default_value,
            type_metadata,
            !notnull,
            default_function,
            collation: collation,
            comment: comment.presence,
            serial: serial,
            spatial: spatial,
            generated: generated,
            hidden: hidden
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

        def create_schema_dumper(options)
          CockroachDB::SchemaDumper.create(self, options)
        end

        def schema_creation
          CockroachDB::SchemaCreation.new(self)
        end
      end
    end
  end
end
