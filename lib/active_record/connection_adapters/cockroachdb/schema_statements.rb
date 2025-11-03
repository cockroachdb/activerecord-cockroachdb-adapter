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

        # OVERRIDE(v8.1.1):
        #   - prepend Utils with PostgreSQL::
        #   - handle hidden attributes
        # Returns an array of indexes for the given table.
        def indexes(table_name) # :nodoc:
          scope = quoted_scope(table_name)

          result = query(<<~SQL, "SCHEMA")
            SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid),
                            pg_catalog.obj_description(i.oid, 'pg_class') AS comment, d.indisvalid,
                            ARRAY(
                              SELECT pg_get_indexdef(d.indexrelid, k + 1, true)
                              FROM generate_subscripts(d.indkey, 1) AS k
                              ORDER BY k
                            ) AS columns,
                            ARRAY(
                              SELECT a.attname
                              FROM pg_attribute a
                              WHERE a.attrelid = d.indexrelid AND a.attishidden
                            ) AS hidden_columns
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE i.relkind IN ('i', 'I')
              AND d.indisprimary = 'f'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
            ORDER BY i.relname
          SQL

          unquote = -> (column) {
            PostgreSQL::Utils.unquote_identifier(column.strip.gsub('""', '"'))
          }
          result.map do |row|
            index_name = row[0]
            unique = row[1]
            indkey = row[2].split(" ").map(&:to_i)
            inddef = row[3]
            comment = row[4]
            valid = row[5]
            columns = decode_string_array(row[6]).map(&unquote)
            hidden_columns = decode_string_array(row[7]).map(&unquote)

            using, expressions, include, nulls_not_distinct, where = inddef.scan(/ USING (\w+?) \((.+?)\)(?: INCLUDE \((.+?)\))?( NULLS NOT DISTINCT)?(?: WHERE (.+))?\z/m).flatten

            orders = {}
            opclasses = {}
            include_columns = include ? include.split(",").map(&unquote) : []

            if indkey.include?(0)
              columns = expressions
            else
              # prevent INCLUDE and hidden columns from being matched
              columns.reject! { |c| include_columns.include?(c) || hidden_columns.include?(c) }

              # add info on sort order (only desc order is explicitly specified, asc is the default)
              # and non-default opclasses
              expressions.scan(/(?<column>\w+)"?\s?(?<opclass>\w+_ops(_\w+)?)?\s?(?<desc>DESC)?\s?(?<nulls>NULLS (?:FIRST|LAST))?/).each do |column, opclass, desc, nulls|
                opclasses[column] = opclass.to_sym if opclass
                if nulls
                  orders[column] = [desc, nulls].compact.join(" ")
                else
                  orders[column] = :desc if desc
                end
              end
            end

            IndexDefinition.new(
              table_name,
              index_name,
              unique,
              columns,
              orders: orders,
              opclasses: opclasses,
              where: where,
              using: using.to_sym,
              include: include_columns.presence,
              nulls_not_distinct: nulls_not_distinct.present?,
              comment: comment.presence,
              valid: valid
            )
          end
        end

        # OVERRIDE: We do not want to see the crdb_internal schema in the names.
        #
        # Returns an array of schema names.
        def schema_names
          super - ["crdb_internal"]
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

        # OVERRIDE(v8.1.1): handle hidden attributes
        def primary_keys(table_name)
          query_values(<<~SQL, "SCHEMA")
            SELECT a.attname
            FROM pg_index i
            JOIN pg_attribute a
              ON a.attrelid = i.indrelid
              AND a.attnum = ANY(i.indkey)
              AND NOT a.attishidden
            WHERE i.indrelid = #{quote(quote_table_name(table_name))}::regclass
              AND i.indisprimary
            ORDER BY array_position(i.indkey, a.attnum)
          SQL
        end

        # OVERRIDE: CockroachDB does not support deferrable constraints.
        #   See: https://go.crdb.dev/issue-v/31632/v23.1
        def foreign_key_options(from_table, to_table, options)
          options = super
          options.delete(:deferrable) unless supports_deferrable_constraints?
          options
        end

        # OVERRIDE(v8.1.1): Added `unique_rowid` to the last line of the second query.
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
                 pg_namespace  nsp
            WHERE seq.oid           = dep.objid
              AND seq.relkind       = 'S'
              AND attr.attrelid     = dep.refobjid
              AND attr.attnum       = dep.refobjsubid
              AND attr.attrelid     = cons.conrelid
              AND attr.attnum       = cons.conkey[1]
              AND seq.relnamespace  = nsp.oid
              AND cons.contype      = 'p'
              AND dep.classid       = 'pg_class'::regclass
              AND dep.refobjid      = #{quote(quote_table_name(table))}::regclass
              AND not attr.attishidden
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
              WHERE t.oid = #{quote(quote_table_name(table))}::regclass
                AND NOT attr.attishidden
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

        # OVERRIDE(v8.1.1):
        #   - Replaces t2.oid::regclass::text with t2.relname
        #     since this is more efficient in CockroachDB.
        #   - prepend schema name to relname (see `AS to_table`)
        #   - handle hidden attributes.
        #
        # NOTE: If you edit this method, you'll need to edit
        #   the `#all_foreign_keys` method as well.
        def foreign_keys(table_name)
          scope = quoted_scope(table_name)
          fk_info = internal_exec_query(<<~SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
            SELECT CASE
              WHEN n2.nspname = current_schema()
              THEN ''
              ELSE n2.nspname || '.'
            END || t2.relname AS to_table,
            c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred, c.conrelid, c.confrelid,
              (
                SELECT array_agg(a.attname ORDER BY idx)
                FROM (
                  SELECT idx, c.conkey[idx] AS conkey_elem
                  FROM generate_subscripts(c.conkey, 1) AS idx
                ) indexed_conkeys
                JOIN pg_attribute a ON a.attrelid = t1.oid
                AND a.attnum = indexed_conkeys.conkey_elem
                AND NOT a.attishidden
              ) AS conkey_names,
              (
                SELECT array_agg(a.attname ORDER BY idx)
                FROM (
                  SELECT idx, c.confkey[idx] AS confkey_elem
                  FROM generate_subscripts(c.confkey, 1) AS idx
                ) indexed_confkeys
                JOIN pg_attribute a ON a.attrelid = t2.oid
                AND a.attnum = indexed_confkeys.confkey_elem
                AND NOT a.attishidden
              ) AS confkey_names
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_namespace n1 ON t1.relnamespace = n1.oid
            JOIN pg_namespace n2 ON t2.relnamespace = n2.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{scope[:name]}
              AND n1.nspname = #{scope[:schema]}
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            to_table = PostgreSQL::Utils.unquote_identifier(row["to_table"])

            column = decode_string_array(row["conkey_names"])
            primary_key = decode_string_array(row["confkey_names"])

            options = {
              column: column.size == 1 ? column.first : column,
              name: row["name"],
              primary_key: primary_key.size == 1 ? primary_key.first : primary_key
            }

            options[:on_delete] = extract_foreign_key_action(row["on_delete"])
            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:deferrable] = extract_constraint_deferrable(row["deferrable"], row["deferred"])

            options[:validate] = row["valid"]

            ForeignKeyDefinition.new(table_name, to_table, options)
          end
        end

        # CockroachDB uses unique_rowid() for primary keys, not sequences. It's
        # possible to force a table to use sequences, but since it's not the
        # default behavior we'll always return nil for default_sequence_name.
        def default_sequence_name(table_name, pk = "id")
          nil
        end

        # OVERRIDE(v8.1.1): handle hidden attributes
        #
        # Returns an array of unique constraints for the given table.
        # The unique constraints are represented as UniqueConstraintDefinition objects.
        def unique_constraints(table_name)
          scope = quoted_scope(table_name)

          unique_info = internal_exec_query(<<~SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
            SELECT c.conname, c.conrelid, c.condeferrable, c.condeferred, pg_get_constraintdef(c.oid) AS constraintdef,
            (
              SELECT array_agg(a.attname ORDER BY idx)
              FROM (
                SELECT idx, c.conkey[idx] AS conkey_elem
                FROM generate_subscripts(c.conkey, 1) AS idx
              ) indexed_conkeys
              JOIN pg_attribute a ON a.attrelid = t.oid
              AND a.attnum = indexed_conkeys.conkey_elem
              AND NOT a.attishidden
            ) AS conkey_names
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON n.oid = c.connamespace
            WHERE c.contype = 'u'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
          SQL

          unique_info.map do |row|
            columns = decode_string_array(row["conkey_names"])

            nulls_not_distinct = row["constraintdef"].start_with?("UNIQUE NULLS NOT DISTINCT")
            deferrable = extract_constraint_deferrable(row["condeferrable"], row["condeferred"])

            options = {
              name: row["conname"],
              nulls_not_distinct: nulls_not_distinct,
              deferrable: deferrable
            }

            UniqueConstraintDefinition.new(table_name, columns, options)
          end
        end

        # OVERRIDE(v8.1.1):
        #   - Add hidden information
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

          CockroachDB::Column.new(
            column_name,
            get_oid_type(oid.to_i, fmod.to_i, column_name, type),
            default_value,
            type_metadata,
            !notnull,
            default_function,
            collation: collation,
            comment: comment.presence,
            serial: serial,
            identity: identity.presence,
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

        # override
        def create_table_definition(*args, **kwargs)
          CockroachDB::TableDefinition.new(self, *args, **kwargs)
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
