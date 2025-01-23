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
        def all_foreign_keys_valid?
          true
        end

        def disable_referential_integrity
          foreign_keys = all_foreign_keys

          statements = foreign_keys.map do |foreign_key|
            # We do not use the `#remove_foreign_key` method here because it
            # checks for foreign keys existance in the schema cache. This method
            # is performance critical and we know the foreign key exist.
            at = create_alter_table foreign_key.from_table
            at.drop_foreign_key foreign_key.name

            schema_creation.accept(at)
          end
          execute_batch(statements, "Disable referential integrity -> remove foreign keys")

          yield

          # Prefixes and suffixes are added in add_foreign_key
          # in AR7+ so we need to temporarily disable them here,
          # otherwise prefixes/suffixes will be erroneously added.
          old_prefix = ActiveRecord::Base.table_name_prefix
          old_suffix = ActiveRecord::Base.table_name_suffix

          ActiveRecord::Base.table_name_prefix = ""
          ActiveRecord::Base.table_name_suffix = ""

          begin
            # Avoid having PG:DuplicateObject error if a test is ran in transaction.
            # TODO: verify that there is no cache issue related to running this (e.g: fk
            #   still in cache but not in db)
            #
            # We avoid using `foreign_key_exists?` here because it checks the schema cache
            # for every key. This method is performance critical for the test suite, hence
            # we use the `#all_foreign_keys` method that only make one query to the database.
            already_inserted_foreign_keys = all_foreign_keys
            statements = foreign_keys.map do |foreign_key|
              next if already_inserted_foreign_keys.any? { |fk| fk.from_table == foreign_key.from_table && fk.options[:name] == foreign_key.options[:name] }

              options = foreign_key_options(foreign_key.from_table, foreign_key.to_table, foreign_key.options)
              at = create_alter_table foreign_key.from_table
              at.add_foreign_key foreign_key.to_table, options

              schema_creation.accept(at)
            end
            execute_batch(statements.compact, "Disable referential integrity -> add foreign keys")
          ensure
            ActiveRecord::Base.table_name_prefix = old_prefix
            ActiveRecord::Base.table_name_suffix = old_suffix
          end
        end

        private

        # Copy/paste of the `#foreign_keys(table)` method adapted to return every single
        # foreign key in the database.
        def all_foreign_keys
          fk_info = exec_query(<<~SQL, "SCHEMA")
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
            a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred,
            c.conkey, c.confkey, c.conrelid, c.confrelid
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            JOIN pg_namespace n1 ON t1.relnamespace = n1.oid
            JOIN pg_namespace n2 ON t2.relnamespace = n2.oid
            WHERE c.contype = 'f'
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            from_table = PostgreSQL::Utils.unquote_identifier(row["from_table"])
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
            options[:deferrable] = extract_foreign_key_deferrable(row["deferrable"], row["deferred"])

            options[:validate] = row["valid"]

            ForeignKeyDefinition.new(from_table, to_table, options)
          end
        end
      end
    end
  end
end
