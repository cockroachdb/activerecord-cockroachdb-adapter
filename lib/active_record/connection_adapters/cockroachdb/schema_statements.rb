module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements

        def add_index(table_name, column_name, options = {})
          super
        rescue ActiveRecord::StatementInvalid => error
          if debugging? && error.cause.class == PG::FeatureNotSupported
            warn "#{error}\n\nThis error will be ignored and the index will not be created.\n\n"
          else
            raise error
          end
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

        # CockroachDB uses unique_rowid() for primary keys, not sequences. It's
        # possible to force a table to use sequences, but since it's not the
        # default behavior we'll always return nil for default_sequence_name.
        def default_sequence_name(table_name, pk = "id")
          nil
        end

        # CockroachDB will use INT8 if the SQL type is INTEGER, so we make it use
        # INT4 explicitly when needed.
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
            else
              super
            end
          # The call to super might have appeneded [] already.
          if array && type != :primary_key && !sql.end_with?("[]")
            sql = "#{sql}[]"
          end
          sql
        end

        # This overrides the method from PostegreSQL adapter
        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil)
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
              minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
            end

            query_value("SELECT setval(#{quote(quoted_sequence)}, #{max_pk ? max_pk : minvalue}, #{max_pk ? true : false})", "SCHEMA")
          end
        end
      end
    end
  end
end
