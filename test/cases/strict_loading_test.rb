# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/computer"
require "models/mentor"
require "models/project"
require "models/ship"
require "models/strict_zine"
require "models/interest"

module CockroachDB
  class StrictLoadingFixturesTest < ActiveRecord::TestCase
    # This test is identical to the ActiveRecord version except
    # that transactional tests are disabled, so create_fixtures
    # will work.
    self.use_transactional_tests = false

    fixtures :strict_zines

    test "strict loading violations are ignored on fixtures" do
      ActiveRecord::FixtureSet.reset_cache
      create_fixtures("strict_zines")

      assert_nothing_raised do
        strict_zines(:going_out).interests.to_a
      end

      assert_raises(ActiveRecord::StrictLoadingViolationError) do
        StrictZine.first.interests.to_a
      end
    end
  end
end
