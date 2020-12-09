require "cases/helper_cockroachdb"

# require "cases/helper"
# require "models/pirate"
# require "models/parrot"
# require "models/treasure"
require "support/connection_helper"

require "models/computer"
require "models/developer"
require "models/project"
require "models/company"
require "models/categorization"
require "models/category"
require "models/post"
require "models/author"
require "models/comment"
require "models/tag"
require "models/tagging"
require "models/person"
require "models/reader"
require "models/ship_part"
require "models/ship"
require "models/liquid"
require "models/molecule"
require "models/electron"
# require "models/human"
require "models/interest"
require "models/pirate"
require "models/parrot"
require "models/bird"
require "models/treasure"
require "models/price_estimate"

require 'pry'
require 'readline'

module CockroachDB
  class WithAnnotationsTest < ActiveRecord::TestCase
    # self.use_instantiated_fixtures = true
    # self.use_transactional_tests = false
    self.use_transactional_tests = false
    fixtures :pirates, :treasures, :parrots

    # def before_setup
    #   Pirate.connection.exec_query("DROP TABLE IF EXISTS parrots_treasures")
    #   Pirate.connection.exec_query("
    #       CREATE TABLE parrots_treasures (
    #         parrot_id INT8 NULL,
    #         treasure_id INT8 NULL
    #       )
    #     ")
    # end

    # def teardown
    #   Arel::Table.engine = ActiveRecord::Base
    # end

    def test_belongs_to_with_annotation_includes_a_query_comment
      # recreate_parrots_treasures
      binding.pry
      pirate = Pirate.where.not(parrot_id: nil).first
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

    private

    def recreate_parrots_treasures
      Pirate.connection.exec_query("DROP TABLE IF EXISTS parrots_treasures")
      Pirate.connection.exec_query("
          CREATE TABLE parrots_treasures (
            parrot_id INT8 NULL,
            treasure_id INT8 NULL
          )
        ")
    end
  end
end
