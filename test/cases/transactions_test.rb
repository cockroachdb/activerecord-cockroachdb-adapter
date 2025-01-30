# frozen_string_literal: true

require "cases/helper_cockroachdb"

module CockroachDB
  class TransactionsTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class Avenger < ActiveRecord::Base
      singleton_class.attr_accessor :cyclic_barrier

      validate :validate_unique_username

      def validate_unique_username
        self.class.cyclic_barrier.wait
        duplicate = self.class.where(name: name).any?
        errors.add("Duplicate username!") if duplicate
      end
    end

    def test_concurrent_insert_with_processes
      conn = ActiveRecord::Base.lease_connection
      conn.create_table :avengers, force: true do |t|
        t.string :name
      end
      ActiveRecord::Base.reset_column_information

      avengers = %w[Hulk Thor Loki]
      Avenger.cyclic_barrier = Concurrent::CyclicBarrier.new(avengers.size - 1)
      Thread.current[:name] = "Main" # For debug logs.

      assert_queries_match(/ROLLBACK/) do # Ensure we are properly testing the retry mechanism.
        avengers.map do |name|
          Thread.fork do
            Thread.current[:name] = name # For debug logs.
            Avenger.create!(name: name)
          end
        end.each(&:join)
      end

      assert_equal avengers.size, Avenger.count
    ensure
      Thread.current[:name] = nil
      conn = ActiveRecord::Base.lease_connection
      conn.drop_table :avengers, if_exists: true
    end
  end
end
