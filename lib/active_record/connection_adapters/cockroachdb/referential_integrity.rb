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

        def disable_referential_integrity
          if transaction_open? && query_value("SHOW autocommit_before_ddl") == "off"
            begin
              yield
            rescue ActiveRecord::InvalidForeignKey => e
              warn <<-WARNING
WARNING: Rails was not able to disable referential integrity.

This is due to CockroachDB's need of committing transactions
before a schema change occurs. To bypass this, you can set
`autocommit_before_ddl: "on"` in your database configuration.
WARNING
              raise e
            end
          else
            foreign_keys = all_foreign_keys

            remove_foreign_keys(foreign_keys)

            # Prefixes and suffixes are added in add_foreign_key
            # in AR7+ so we need to temporarily disable them here,
            # otherwise prefixes/suffixes will be erroneously added.
            old_prefix = ActiveRecord::Base.table_name_prefix
            old_suffix = ActiveRecord::Base.table_name_suffix

            begin
              yield
            ensure
              ActiveRecord::Base.table_name_prefix = ""
              ActiveRecord::Base.table_name_suffix = ""

              add_foreign_keys(foreign_keys) # Never raises.

              ActiveRecord::Base.table_name_prefix = old_prefix if defined?(old_prefix)
              ActiveRecord::Base.table_name_suffix = old_suffix if defined?(old_suffix)
            end
          end
        end

        private

        def remove_foreign_keys(foreign_keys)
          statements = foreign_keys.map do |foreign_key|
            # We do not use the `#remove_foreign_key` method here because it
            # checks for foreign keys existance in the schema cache. This method
            # is performance critical and we know the foreign key exist.
            at = create_alter_table foreign_key.from_table
            at.drop_foreign_key foreign_key.name

            schema_creation.accept(at)
          end
          with_schema_unlocked(foreign_keys.flat_map { |fk| [fk.from_table, fk.to_table] }) do
            execute_batch(statements, "Disable referential integrity -> remove foreign keys")
          end
        end

        # NOTE: This method should never raise, otherwise we risk polluting table name
        #   prefixes and suffixes. The good thing is: if this happens, tests will crash
        #   hard, no way we miss it.
        def add_foreign_keys(foreign_keys)
          # We avoid using `foreign_key_exists?` here because it checks the schema cache
          # for every key. This method is performance critical for the test suite, hence
          # we use the `#all_foreign_keys` method that only make one query to the database.
          already_inserted_foreign_keys = all_foreign_keys
          foreign_keys_to_add = foreign_keys.reject do |foreign_key|
            already_inserted_foreign_keys.any? { |fk| fk.from_table == foreign_key.from_table && fk.options[:name] == foreign_key.options[:name] }
          end
          statements = foreign_keys_to_add.map do |foreign_key|
            options = foreign_key_options(foreign_key.from_table, foreign_key.to_table, foreign_key.options)
            at = create_alter_table foreign_key.from_table
            at.add_foreign_key foreign_key.to_table, options

            schema_creation.accept(at)
          end
          with_schema_unlocked(foreign_keys_to_add.flat_map { |fk| [fk.from_table, fk.to_table] }) do
            execute_batch(statements, "Disable referential integrity -> add foreign keys")
          end
        end

        # Starting in CockroachDB v26.x, tables are created with the
        # `schema_locked` storage parameter enabled by default (it improves
        # changefeed performance). CockroachDB transparently unlocks a table to
        # run a single-statement DDL, but it cannot do so for the multi-statement
        # batches used to drop and re-add foreign keys above: it raises instead
        # of unlocking automatically. So we unlock the affected tables ourselves,
        # run the batch, then restore their locked state. Adding a foreign key
        # also writes a back-reference into the referenced table, so callers must
        # pass both the referencing and referenced tables.
        #
        # See https://www.cockroachlabs.com/docs/stable/schema-locked
        def with_schema_unlocked(tables)
          locked = schema_locked_tables(tables.uniq)
          return yield if locked.empty?

          set_schema_locked(locked, false)
          begin
            yield
          ensure
            set_schema_locked(locked, true)
          end
        end

        # Returns the subset of +tables+ whose `schema_locked` storage parameter
        # is currently enabled. CockroachDB exposes storage parameters through
        # `pg_class.reloptions`. On versions (or configurations) that do not lock
        # tables this returns an empty array, so callers stay on the fast path.
        def schema_locked_tables(tables)
          return [] if tables.empty?

          locked = query_values(<<~SQL, "SCHEMA")
            SELECT (CASE WHEN n.nspname = current_schema() THEN '' ELSE n.nspname || '.' END) || c.relname
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind = 'r' AND 'schema_locked=true' = ANY (c.reloptions)
          SQL
          tables & locked
        end

        # Toggles the `schema_locked` storage parameter for the given tables.
        # CockroachDB only allows changing `schema_locked` in a single-statement
        # implicit transaction, so unlike the foreign key statements above these
        # cannot be batched together.
        def set_schema_locked(tables, value)
          tables.each do |table|
            execute("ALTER TABLE #{quote_table_name(table)} SET (schema_locked = #{value})", "Toggle schema_locked")
          end
        end

        # NOTE: Copy/paste of the `#foreign_keys(table)` method adapted
        #   to return every single foreign key in the database.
        def all_foreign_keys
          fk_info = internal_exec_query(<<~SQL, "SCHEMA")
            SELECT CASE
              WHEN n1.nspname = current_schema()
              THEN ''
              ELSE n1.nspname || '.'
            END || t1.relname AS from_table,
            CASE
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
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            from_table = PostgreSQL::Utils.unquote_identifier(row["from_table"])
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

            ForeignKeyDefinition.new(from_table, to_table, options)
          end
        end
      end
    end
  end
end
