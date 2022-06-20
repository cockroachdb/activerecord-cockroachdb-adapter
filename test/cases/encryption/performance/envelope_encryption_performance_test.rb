# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

module ActiveRecord
  module CockroachDB
    module Encryption
      class EnvelopeEncryptionPerformanceTest < ActiveRecord::EncryptionTestCase
        fixtures :encrypted_books

        setup do
          ActiveRecord::Encryption.config.support_unencrypted_data = true
          @envelope_encryption_key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
        end

        test "performance when saving records" do
          baseline = -> { create_book_without_encryption }

          assert_slower_by_at_most 1.5, baseline: baseline do
            with_envelope_encryption do
              create_book
            end
          end
        end

        private
          def create_book_without_encryption
            ActiveRecord::Encryption.without_encryption { create_book }
          end

          def create_book
            EncryptedBook.create! name: "Dune"
          end

          def encrypt_unencrypted_book
            book = create_book_without_encryption
            with_envelope_encryption do
              book.encrypt
            end
          end

          def with_envelope_encryption(&block)
            with_key_provider @envelope_encryption_key_provider, &block
          end
      end
    end
  end
end
