# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

module ActiveRecord
  module CockroachDB
    module Encryption
      class ExtendedDeterministicQueriesPerformanceTest < ActiveRecord::EncryptionTestCase
        test "finding without prepared statement caching by encrypted columns (deterministic)" do
          baseline = -> { EncryptedBook.where("id > 0").find_by(format: "paperback") } # not encrypted

          # Overhead is 1.1 with SQL
          assert_slower_by_at_most 1.8, baseline: baseline, duration: 2 do
            EncryptedBook.where("id > 0").find_by(name: "Agile Web Development with Rails") # encrypted, deterministic
          end
        end
      end
    end
  end
end
