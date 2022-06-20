# frozen_string_literal: true

require "cases/encryption/helper"

module ActiveRecord
  module CockroachDB
    module Encryption
      class StoragePerformanceTest < ActiveRecord::EncryptionTestCase
        test "storage overload storing keys is acceptable for EnvelopeEncryptionKeyProvider" do
          ActiveRecord::Encryption.config.store_key_references = true

          with_envelope_encryption do
            assert_storage_performance size: 2, overload_less_than: 126
            assert_storage_performance size: 50, overload_less_than: 6.28
            assert_storage_performance size: 255, overload_less_than: 2.3
            assert_storage_performance size: 1.kilobyte, overload_less_than: 1.3

            [500.kilobytes, 1.megabyte, 10.megabyte].each do |size|
              assert_storage_performance size: size, overload_less_than: 1.015
            end
          end
        end

        private
          def assert_storage_performance(size:, overload_less_than:, quiet: true)
            clear_content = SecureRandom.urlsafe_base64(size).first(size) # .alphanumeric is very slow for large sizes
            encrypted_content = encryptor.encrypt(clear_content)

            overload_factor = encrypted_content.bytesize.to_f / clear_content.bytesize

            if !quiet || overload_factor > overload_less_than
              puts "#{clear_content.bytesize}; #{encrypted_content.bytesize}; #{(encrypted_content.bytesize / clear_content.bytesize.to_f)}"
            end

            assert\
              overload_factor <= overload_less_than,
              "Expecting an storage overload of #{overload_less_than} at most for #{size} bytes, but got #{overload_factor} instead"
          end

          def encryptor
            @encryptor ||= ActiveRecord::Encryption::Encryptor.new
          end

          def cipher
            @cipher ||= ActiveRecord::Encryption::Cipher.new
          end
      end
    end
  end
end
