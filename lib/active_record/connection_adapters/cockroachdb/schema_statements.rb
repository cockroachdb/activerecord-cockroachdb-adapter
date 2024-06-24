# frozen_string_literal: true

# Copyright 2024 The Cockroach Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements

        # OVERRIDE: We do not want to see the crdb_internal schema in the names.
        #
        # Returns an array of schema names.
        def schema_names
          super - ["crdb_internal"]
        end

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

        # override
        # Modified version of the postgresql foreign_keys method.
        # Replaces t2.oid::regclass::text with t2.relname since this is
        # more efficient in CockroachDB.
        # Also, CockroachDB does not append the schema name in relname,
        # so we append it manually.
        def foreign_keys(table_name)
          scope = quoted_scope(table_name)
          fk_info = internal_exec_query(<<~SQL, "SCHEMA")
            SELECT CASE
              WHEN n2.nspname = current_schema()
              THEN ''
              ELSE n2.nspname || '.'
            END || t2.relname AS to_table,
            a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred,
            c.conkey, c.confkey, c.conrelid, c.confrelid
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            JOIN pg_namespace n2 ON t2.relnamespace = n2.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{scope[:name]}
              AND t3.nspname = #{scope[:schema]}
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            to_table = PostgreSQL::Utils.unquote_identifier(row["to_table"])
            conkey = row["conkey"].scan(/\d+/).map(&:to_i)
            confkey = row["confkey"].scan(/\d+/).map(&:to_i)

            if conkey.size > 1
              column = column_names_from_column_numbers(row["conrelid"], conkey)
              primary_key = column_names_from_column_numbers(row["confrelid"], confkey)
            else
              column = PostgreSQL::Utils.unquote_identifier(row["column"])
              primary_key = row["primary_key"]
            end

            options = {
              column: column,
              name: row["name"],
              primary_key: primary_key
            }
            options[:on_delete] = extract_foreign_key_action(row["on_delete"])
            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:deferrable] = extract_constraint_deferrable(row["deferrable"], row["deferred"])

            options[:validate] = row["valid"]
            to_table = PostgreSQL::Utils.unquote_identifier(row["to_table"])

            ForeignKeyDefinition.new(table_name, to_table, options)
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
        def new_column_from_field(table_name, field, _definition)
          column_name, type, default, notnull, oid, fmod, collation, comment, identity, attgenerated, hidden = field
          type_metadata = fetch_type_metadata(column_name, type, oid.to_i, fmod.to_i)
          default_value = extract_value_from_default(default)

          if attgenerated.present?
            default_function = default
          else
            default_function = extract_default_function(default_value, default)
          end

          if match = default_function&.match(/\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z/)
            serial = sequence_name_from_parts(table_name, column_name, match[:suffix]) == match[:sequence_name]
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
            identity: identity.presence,
            spatial: spatial,
            generated: attgenerated,
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
