# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module TransactionManagerMonkeyPatch
        # Capture ActiveRecord::SerializationFailure errors caused by
        # transactions that fail due to serialization errors. Failed
        # transactions will be retried until they pass or the max retry limit is
        # exceeded.
        def within_new_transaction(options = {})
          attempts = options.fetch(:attempts, 0)
          super
        rescue ActiveRecord::SerializationFailure => error
          raise if attempts >= @connection.max_transaction_retries

          attempts += 1
          sleep_seconds = (2 ** attempts + rand) / 10
          sleep(sleep_seconds)
          within_new_transaction(options.merge(attempts: attempts)) { yield }
        end
      end
    end

    class TransactionManager
      prepend CockroachDB::TransactionManagerMonkeyPatch
    end
  end
end
