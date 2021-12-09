module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module DatabaseStatements
        # Since CockroachDB will run all transactions with serializable isolation,
        # READ UNCOMMITTED, READ COMMITTED, and REPEATABLE READ are all aliases
        # for SERIALIZABLE. This lets the adapter support all isolation levels,
        # but READ UNCOMMITTED has been removed from this list because the
        # ActiveRecord transaction isolation test fails for READ UNCOMMITTED.
        # See https://www.cockroachlabs.com/docs/v19.2/transactions.html#isolation-levels
        def transaction_isolation_levels
          {
            read_committed:   "READ COMMITTED",
            repeatable_read:  "REPEATABLE READ",
            serializable:     "SERIALIZABLE",
            read_uncommitted: "SERIALIZABLE"
          }
        end

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

        private
          def execute_batch(statements, name = nil)
            statements.each do |statement|
              execute(statement, name)
            end
          end

          DEFAULT_INSERT_VALUE = Arel.sql("DEFAULT").freeze
          private_constant :DEFAULT_INSERT_VALUE

          def default_insert_value(column)
            DEFAULT_INSERT_VALUE
          end

          def build_fixture_sql(fixtures, table_name)
            columns = schema_cache.columns_hash(table_name)

            values_list = fixtures.map do |fixture|
              fixture = fixture.stringify_keys

              unknown_columns = fixture.keys - columns.keys
              if unknown_columns.any?
                raise Fixture::FixtureError, %(table "#{table_name}" has no columns named #{unknown_columns.map(&:inspect).join(', ')}.)
              end

              columns.map do |name, column|
                if fixture.key?(name)
                  type = lookup_cast_type_from_column(column)
                  with_yaml_fallback(type.serialize(fixture[name]))
                else
                  default_insert_value(column)
                end
              end
            end

            table = Arel::Table.new(table_name)
            manager = Arel::InsertManager.new
            manager.into(table)

            if values_list.size == 1
              values = values_list.shift
              new_values = []
              columns.each_key.with_index { |column, i|
                unless values[i].equal?(DEFAULT_INSERT_VALUE)
                  new_values << values[i]
                  manager.columns << table[column]
                end
              }
              values_list << new_values
            else
              columns.each_key { |column| manager.columns << table[column] }
            end

            manager.values = manager.create_values_list(values_list)
            manager.to_sql
          end

          def build_fixture_statements(fixture_set)
            fixture_set.map do |table_name, fixtures|
              next if fixtures.empty?
              build_fixture_sql(fixtures, table_name)
            end.compact
          end

          def with_multi_statements
            yield
          end
      end
    end
  end
end
