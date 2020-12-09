require "cases/helper_cockroachdb"

require "support/connection_helper"

require "models/pirate"
require "models/parrot"
require "models/treasure"

module CockroachDB
  class WithAnnotationsTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    fixtures :pirates, :treasures, :parrots

    def test_belongs_to_with_annotation_includes_a_query_comment
      pirate = SpacePirate.where.not(parrot_id: nil).first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.parrot
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* that tells jokes \*/}) do
        pirate.parrot_with_annotation
      end
    end
  end
end
