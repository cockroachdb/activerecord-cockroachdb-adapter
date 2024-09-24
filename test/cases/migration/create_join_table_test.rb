# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module CockroachDB
    class Migration
      class CreateJoinTableTest < ActiveRecord::TestCase
        attr_reader :connection

        self.use_transactional_tests = false

        def setup
          super
          @connection = ActiveRecord::Base.lease_connection
        end

        teardown do
          %w(artists_musics musics_videos catalog).each do |table_name|
            connection.drop_table table_name, if_exists: true
          end
        end

        # This test is identical to the one found in Rails, save for the fact
        # that transactions are turned off for test runs. It is necessary to disable
        # transactional tests in order to assert on schema changes due to how
        # CockroachDB handles transactions.
        def test_create_join_table_with_index
          connection.create_join_table :artists, :musics do |t|
            t.index [:artist_id, :music_id]
          end

          assert_equal [%w(artist_id music_id)], connection.indexes(:artists_musics).map(&:columns)
        end

        # This test is identical to the one found in Rails, save for the fact
        # that transactions are turned off for test runs. It is necessary to disable
        # transactional tests in order to assert on schema changes due to how
        # CockroachDB handles transactions.
        def test_create_and_drop_join_table_with_common_prefix
          with_table_cleanup do
            connection.create_join_table "audio_artists", "audio_musics"
            assert connection.table_exists?("audio_artists_musics")

            connection.drop_join_table "audio_artists", "audio_musics"
            assert !connection.table_exists?("audio_artists_musics"), "Should have dropped join table, but didn't"
          end
        end

        private

        def with_table_cleanup
          tables_before = connection.data_sources

          yield
        ensure
          tables_after = connection.data_sources - tables_before

          tables_after.each do |table|
            connection.drop_table table
          end
        end
      end
    end
  end
end
