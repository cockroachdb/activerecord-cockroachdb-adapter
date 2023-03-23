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
          super(isolation: isolation, joinable: joinable)
        rescue ActiveRecord::ConnectionNotEstablished => error
          raise unless retryable? error
          raise if attempts >= @connection.max_transaction_retries

          sleep_rand_seconds(attempts)

          unless @connection.active?
            warn "connection isn't active, reconnecting"
            @connection.reconnect!
          end

          within_new_transaction(isolation: isolation, joinable: joinable, attempts: attempts + 1) { yield }
        rescue ActiveRecord::StatementInvalid => error
          raise unless retryable? error
          raise if attempts >= @connection.max_transaction_retries

          sleep_rand_seconds(attempts)

          within_new_transaction(isolation: isolation, joinable: joinable, attempts: attempts + 1) { yield }
        end

        def retryable?(error)
          return true if serialization_error?(error)
          return true if error.is_a? ActiveRecord::SerializationFailure
          return retryable? error.cause if error.cause
          false
        end

        def serialization_error?(error)
          errors = [error]
          errors << error.cause if error.cause
          errors.any? {|e| e.is_a? PG::TRSerializationFailure }
        end

        def sleep_rand_seconds(attempts)
          sleep_seconds = (2 ** attempts + rand) / 10
          sleep(sleep_seconds)
        end
      end
    end

    class TransactionManager
      prepend CockroachDB::TransactionManagerMonkeyPatch
    end
  end
end
