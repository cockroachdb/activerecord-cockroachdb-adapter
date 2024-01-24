module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module DatabaseStatements
        # Overridden to avoid using transactions for schema creation.
        def insert_fixtures_set(fixture_set, tables_to_delete = [])
          fixture_inserts = build_fixture_statements(fixture_set)
          table_deletes = tables_to_delete.map { |table| "DELETE FROM #{quote_table_name(table)}" }
          statements = table_deletes + fixture_inserts

          with_multi_statements do
            disable_referential_integrity do
              execute_batch(statements, "Fixtures Load")
            end
          end
        end
      end
    end
  end
end
