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
      module DatabaseStatements
        # Overridden to avoid using transactions for schema creation.
        def insert_fixtures_set(fixture_set, tables_to_delete = [])
          fixture_inserts = build_fixture_statements(fixture_set)
          table_deletes = tables_to_delete.map { |table| "DELETE FROM #{quote_table_name(table)}" }
          statements = (table_deletes + fixture_inserts).join(";")

          # Since [rails pull request #52428][1], `#execute_batch` does not
          # trigger a cache clear anymore. However, `#insert_fixtures_set`
          # relies on that clear to ensure consistency. In the postgresql
          # adapter, this is ensured by a call to `#execute` rather than
          # `#execute_batch` in `#disable_referential_integrity`. Since
          # we are not always calling `#disable_referential_integrity`,
          # we need to ensure that the cache is cleared when running
          # our statements by calling `#execute` instead of `#execute_batch`.
          #
          # [1]: https://github.com/rails/rails/pull/52428
          begin # much faster without disabling referential integrity, worth trying.
            transaction(requires_new: true) do
              execute(statements, "Fixtures Load")
            end
          rescue
            disable_referential_integrity do
              execute(statements, "Fixtures Load")
            end
          end
        end
      end
    end
  end
end
