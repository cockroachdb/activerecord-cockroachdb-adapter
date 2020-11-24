require "cases/helper_cockroachdb"
require "cases/helper"

module ActiveRecord
  module CockroachDB
    class SanitizeTest < ActiveRecord::TestCase
      def test_bind_range
        quoted_abc = %(#{ActiveRecord::Base.connection.quote('a')},#{ActiveRecord::Base.connection.quote('b')},#{ActiveRecord::Base.connection.quote('c')})
        assert_equal "'0'", bind("?", 0..0)
        assert_equal "'1','2','3'", bind("?", 1..3)
        assert_equal quoted_abc, bind("?", "a"..."d")
      end

      private

      def bind(statement, *vars)
        if vars.first.is_a?(Hash)
          ActiveRecord::Base.send(:replace_named_bind_variables, statement, vars.first)
        else
          ActiveRecord::Base.send(:replace_bind_variables, statement, vars)
        end
      end
    end
  end
end