require "cases/helper_cockroachdb"

require "support/connection_helper"

require "models/bird"
require "models/parrot"
require "models/pirate"
require "models/price_estimate"
require "models/ship"
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

    def test_has_and_belongs_to_many_with_annotation_includes_a_query_comment
      pirate = SpacePirate.first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.parrots.first
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* that are very colorful \*/}) do
        pirate.parrots_with_annotation.first
      end
    end

    def test_has_one_with_annotation_includes_a_query_comment
      pirate = SpacePirate.first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.ship
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* that is a rocket \*/}) do
        pirate.ship_with_annotation
      end
    end

    def test_has_many_with_annotation_includes_a_query_comment
      pirate = SpacePirate.first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.birds.first
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* that are also parrots \*/}) do
        pirate.birds_with_annotation.first
      end
    end

    def test_has_many_through_with_annotation_includes_a_query_comment
      pirate = SpacePirate.first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.treasure_estimates.first
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* yarrr \*/}) do
        pirate.treasure_estimates_with_annotation.first
      end
    end

    def test_has_many_through_with_annotation_includes_a_query_comment_when_eager_loading
      pirate = SpacePirate.first
      assert pirate, "should have a Pirate record"

      log = capture_sql do
        pirate.treasure_estimates.first
      end
      assert_not_predicate log, :empty?
      assert_predicate log.select { |query| query.match?(%r{/\*}) }, :empty?

      assert_sql(%r{/\* yarrr \*/}) do
        SpacePirate.includes(:treasure_estimates_with_annotation, :treasures).first
      end
    end
  end
end
