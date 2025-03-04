# frozen_string_literal: true

# Copyright 2024 The Cockroach Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

        # OVERRIDE: the `rescue ActiveRecord::StatementInvalid` block is new, see comment.
        def rollback_transaction(transaction = nil)
          @connection.lock.synchronize do
            transaction ||= @stack.last
            begin
              transaction.rollback
            rescue ActiveRecord::StatementInvalid => err
              # This is important to make Active Record aware the record was not inserted/saved
              # Otherwise Active Record will assume save was successful and it doesn't retry the transaction
              # See this thread for more details:
              # https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/258#issuecomment-2256633329
              transaction.rollback_records if err.cause.is_a?(PG::NoActiveSqlTransaction)

              raise
            ensure
              @stack.pop if @stack.last == transaction
            end
            transaction.rollback_records
          end
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
