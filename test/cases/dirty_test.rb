require "cases/helper"

module CockroachDB
  class DirtyTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    class Testings < ActiveRecord::Base; end

    # This replaces the same test that's been excluded from DirtyTest. We can
    # run it here with use_transactional_tests set to false.
    # See test/excludes/DirtyTest.rb
    def test_field_named_field
      ActiveRecord::Base.lease_connection.create_table :testings do |t|
        t.string :field
      end
      assert_nothing_raised do
        Testings.new.attributes
      end
    ensure
      ActiveRecord::Base.lease_connection.drop_table :testings, if_exists: true
      ActiveRecord::Base.clear_cache!
    end
  end
end
