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
            serializable:     "SERIALIZABLE"
          }
        end
      end
    end
  end
end
