# frozen_string_literal: true

require "cases/helper_cockroachdb"


module ActiveRecord
  module CockroachDB
    class PostgresqlConnectionTest < ActiveRecord::PostgreSQLTestCase
      include ConnectionHelper

      def test_set_session_variable_true
        run_without_connection do |orig_connection|
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { null_ordered_last: true }))
          set_true = ActiveRecord::Base.connection.exec_query "SHOW NULL_ORDERED_LAST"
          assert_equal [["on"]], set_true.rows
        end
      end

      def test_set_session_variable_false
        run_without_connection do |orig_connection|
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { null_ordered_last: false }))
          set_false = ActiveRecord::Base.connection.exec_query "SHOW NULL_ORDERED_LAST"
          assert_equal [["off"]], set_false.rows
        end
      end

      def test_set_session_variable_nil
        run_without_connection do |orig_connection|
          # This should be a no-op that does not raise an error
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { null_ordered_last: nil }))
        end
      end

      def test_set_session_variable_default
        run_without_connection do |orig_connection|
          # This should execute a query that does not raise an error
          ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { null_ordered_last: :default }))
        end
      end
    end
  end
end
