module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module OID
        module TypeMapInitializer
          # override
          # Replaces the query with a faster version that doesn't rely on the
          # use of 'array_in(cstring,oid,integer)'::regprocedure.
          def query_conditions_for_initial_load
            known_type_names = @store.keys.map { |n| "'#{n}'" }
            known_type_types = %w('r' 'e' 'd')
            <<~SQL % [known_type_names.join(", "), known_type_types.join(", ")]
              WHERE
                t.typname IN (%s)
                OR t.typtype IN (%s)
                OR (t.typarray = 0 AND t.typcategory='A')
                OR t.typelem != 0
            SQL
          end
        end

        PostgreSQL::OID::TypeMapInitializer.prepend(TypeMapInitializer)
      end
    end
  end
end
