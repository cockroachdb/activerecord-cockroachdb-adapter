require 'active_record/connection_adapters/postgresql/schema_statements'

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements
        # NOTE(joey): This was ripped from PostgresSQL::SchemaStatements, with a
        # slight modification to change setval(string, int, bool) to just
        # setval(string, int) for CockroachDB compatbility.
        # See https://github.com/cockroachdb/cockroach/issues/19723
        #
        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
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
              if postgresql_version >= 100000
                minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
              else
                minvalue = query_value("SELECT min_value FROM #{quoted_sequence}", "SCHEMA")
              end
            end
            if max_pk
              # NOTE(joey): This is done to replace the call:
              #
              #    SELECT setval(..., max_pk, false)
              #
              # with
              #
              #    SELECT setval(..., max_pk-1)
              #
              # These two statements are semantically equivilant, but
              # setval(string, int, bool) is not supported by CockroachDB.
              #
              # FIXME(joey): This is incorrect if the sequence is not 1
              # incremented. We would need to pull out the custom increment value.
              max_pk - 1
            end
            query_value("SELECT setval(#{quote(quoted_sequence)}, #{max_pk ? max_pk : minvalue})", "SCHEMA")
          end
        end
      end
    end
  end
end
