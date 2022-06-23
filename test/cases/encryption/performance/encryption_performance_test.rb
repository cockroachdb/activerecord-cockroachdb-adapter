# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "models/post_encrypted"

module ActiveRecord
  module CockroachDB
    module Encryption
      class EncryptionPerformanceTest < ActiveRecord::EncryptionTestCase
        fixtures :encrypted_books, :posts

        setup do
          ActiveRecord::Encryption.config.support_unencrypted_data = true
        end

        test "reading an encrypted attribute multiple times is as fast as reading a regular attribute" do
          unencrypted_post = create_post_without_encryption
          baseline = -> { unencrypted_post.reload.title }

          encrypted_post = create_post_with_encryption
          assert_slower_by_at_most 1.3, baseline: baseline, duration: 3 do
            encrypted_post.reload.title
          end
        end

        private
          def create_post_without_encryption
            ActiveRecord::Encryption.without_encryption { create_post_with_encryption }
          end

          def create_post_with_encryption
            EncryptedPost.create!\
              title: "the Starfleet is here!",
              body: "<p>the Starfleet is here, we are safe now!</p>"
          end
      end
    end
  end
end
