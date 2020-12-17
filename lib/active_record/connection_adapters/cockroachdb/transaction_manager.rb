# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module TransactionManagerMonkeyPatch
        # Capture ActiveRecord::SerializationFailure errors caused by
        # transactions that fail due to serialization errors. Failed
        # transactions will be retried until they pass or the max retry limit is
        # exceeded.
        def within_new_transaction(isolation: nil, joinable: true, attempts: 0)
          super
        rescue ActiveRecord::StatementInvalid => error
          raise unless retryable? error
          raise if attempts >= @connection.max_transaction_retries

          attempts += 1
          sleep_seconds = (2 ** attempts + rand) / 10
          sleep(sleep_seconds)
          within_new_transaction(isolation: isolation, joinable: joinable, attempts: attempts) { yield }
        end

        def retryable?(error)
          return true if error.is_a? ActiveRecord::SerializationFailure
          return retryable? error.cause if error.cause
          false
        end
      end
    end

    class TransactionManager
      prepend CockroachDB::TransactionManagerMonkeyPatch
    end
  end
end
