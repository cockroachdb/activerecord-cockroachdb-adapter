module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module PostgreSQLColumnMonkeyPatch
        def serial?
          default_function == "unique_rowid()"
        end
      end
    end

    class PostgreSQLColumn
      prepend CockroachDB::PostgreSQLColumnMonkeyPatch
    end
  end
end
