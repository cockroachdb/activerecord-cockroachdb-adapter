module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module SchemaStatements
        include ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements

        DEFAULT_PRIMARY_KEY = "rowid"

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

          if pk == DEFAULT_PRIMARY_KEY
            nil
          else
            pk
          end
        end

        # copied from ConnectionAdapters::SchemaStatements
        #
        # modified insert into statement to always wrap the version value into single quotes for cockroachdb.
        def assume_migrated_upto_version(version, migrations_paths)
          migrations_paths = Array(migrations_paths)
          version = version.to_i

          migrated = ActiveRecord::SchemaMigration.all_versions.map(&:to_i)
          versions = migration_context.migration_files.map do |file|
            migration_context.parse_migration_filename(file).first.to_i
          end

          unless migrated.include?(version)
            execute insert_versions_sql(version)
          end

          inserting = (versions - migrated).select { |v| v < version }
          if inserting.any?
            if (duplicate = inserting.detect { |v| inserting.count(v) > 1 })
              raise "Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict."
            end
            if supports_multi_insert?
              execute insert_versions_sql(inserting)
            else
              inserting.each do |v|
                execute insert_versions_sql(v)
              end
            end
          end
        end

        def insert_versions_sql(versions)
          sm_table = quote_table_name(ActiveRecord::SchemaMigration.table_name)
          if versions.is_a?(Array)
            sql = "INSERT INTO #{sm_table} (version) VALUES\n".dup
            sql << versions.map { |v| "('#{quote(v)}')" }.join(",\n")
            sql << ";\n\n"
            sql
          else
            "INSERT INTO #{sm_table} (version) VALUES ('#{quote(versions)}');"
          end
        end
      end
    end
  end
end
