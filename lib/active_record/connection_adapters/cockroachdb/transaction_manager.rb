# frozen_string_literal: true

require 'active_record/connection_adapters/abstract/transaction'

module ActiveRecord
  module ConnectionAdapters

    # NOTE(joey): This is a very sad monkey patch. Unfortunately, it is
    # required in order to prevent doing more than 2 nested transactions
    # while still allowing a single nested transaction. This is because
    # CockroachDB only supports a single savepoint at the beginning of a
    # transaction. Allowing this works for the common case of testing.
    module CockroachDB
      module TransactionManagerMonkeyPatch
        def begin_transaction(options={})
          @connection.lock.synchronize do
            # If the transaction nesting is already 2 deep, raise an error.
            if @connection.adapter_name == "CockroachDB" && @stack.is_a?(ActiveRecord::ConnectionAdapters::SavepointTransaction)
              raise(ArgumentError, "cannot nest more than 1 transaction at a time. this is a CockroachDB limitation")
            end
          end
          super(options)
        end
      end
    end

    class TransactionManager
      prepend CockroachDB::TransactionManagerMonkeyPatch
    end
  end
end
