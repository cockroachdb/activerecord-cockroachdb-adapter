# frozen_string_literal: true

require 'cases/helper_cockroachdb'

class NestedClassTest < ActiveRecord::PostgreSQLTestCase
  module Foo
    def self.table_name_prefix
      'foo_'
    end

    class Bar < ActiveRecord::Base
    end
  end

  def test_nested_model
    Foo::Bar.lease_connection.create_table(:foo_bars, force: true) do |t|
      t.column 'latlon', :st_point, srid: 3785
    end
    assert_empty Foo::Bar.all
    Foo::Bar.lease_connection.drop_table(:foo_bars)
  end
end
