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
          foreign_keys = tables.map { |table| foreign_keys(table) }.flatten

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
