# frozen_string_literal: true

# The PostgresSQL Adapter's ReferentialIntegrity module can disable and
# re-enable foreign key constraints by disabling all table triggers. Since
# triggers are not available in CockroachDB, we have to remove foreign keys and
# re-add them via the ActiveRecord API.
#
# This module is commonly used to load test fixture data without having to worry
# about the order in which that data is loaded.
module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module ReferentialIntegrity
        # CockroachDB will raise a `PG::ForeignKeyViolation` when re-enabling
        # referential integrity (e.g: adding a foreign key with invalid data
        # raises).
        # So foreign keys should always be valid for that matter.
        def check_all_foreign_keys_valid!
          true
        end

        def multi_foreign_keys(table_names)
          schemas, names = table_names.map { quoted_scope(_1).values }.transpose.map(&:uniq)
          raise if schemas.size > 1
          fk_info = exec_query(<<~SQL, "SCHEMA")
            SELECT CASE
              WHEN n2.nspname = current_schema()
              THEN ''
              ELSE n2.nspname || '.'
            END || t2.relname AS to_table,
            a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred,
            c.conkey, c.confkey, c.conrelid, c.confrelid,
            t1.relname
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            JOIN pg_namespace n2 ON t2.relnamespace = n2.oid
            WHERE c.contype = 'f'
              AND t1.relname IN (#{names * ","})
              AND t3.nspname = #{schemas.first}
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

            ForeignKeyDefinition.new(row["relname"], to_table, options)
          end
        end

        def disable_referential_integrity
          foreign_keys = multi_foreign_keys(tables)
          foreign_keys.each do |foreign_key|
            remove_foreign_key(foreign_key.from_table, name: foreign_key.options[:name])
          end

          yield

          # Prefixes and suffixes are added in add_foreign_key
          # in AR7+ so we need to temporarily disable them here,
          # otherwise prefixes/suffixes will be erroneously added.
          old_prefix = ActiveRecord::Base.table_name_prefix
          old_suffix = ActiveRecord::Base.table_name_suffix

          ActiveRecord::Base.table_name_prefix = ""
          ActiveRecord::Base.table_name_suffix = ""

          begin
            foreign_keys.each do |foreign_key|
              # Avoid having PG:DuplicateObject error if a test is ran in transaction.
              # TODO: verify that there is no cache issue related to running this (e.g: fk
              #   still in cache but not in db)
              next if foreign_key_exists?(foreign_key.from_table, name: foreign_key.options[:name])

              add_foreign_key(foreign_key.from_table, foreign_key.to_table, **foreign_key.options)
            end
          ensure
            ActiveRecord::Base.table_name_prefix = old_prefix
            ActiveRecord::Base.table_name_suffix = old_suffix
          end
        end
      end
    end
  end
end
