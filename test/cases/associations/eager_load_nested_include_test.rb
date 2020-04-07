# This test has been copied to fix a bug in the test setup. It can be removed
# once the bug has been fixed and released in Rails.
# See test/excludes/EagerLoadPolyAssocsTest.rb

require "cases/helper_cockroachdb"

# Load dependencies from ActiveRecord test suite
require "cases/helper"
require "models/post"
require "models/tag"
require "models/author"
require "models/comment"
require "models/category"
require "models/categorization"
require "models/tagging"

module CockroachDB
  module Remembered
    extend ActiveSupport::Concern

    included do
      after_create :remember
    private
      def remember; self.class.remembered << self; end
    end

    module ClassMethods
      # The test setup bug is fixed here. @@remembered was being shared by every
      # class that included the Remembered module. Instead, we can use
      # @remembered which will be unique to each included class.
      def remembered; @remembered ||= []; end
      def sample; remembered.sample; end
    end
  end

  class ShapeExpression < ActiveRecord::Base
    belongs_to :shape, polymorphic: true
    belongs_to :paint, polymorphic: true
  end

  class Circle < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end
  class Square < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end
  class Triangle < ActiveRecord::Base
    has_many :shape_expressions, as: :shape
    include Remembered
  end
  class PaintColor < ActiveRecord::Base
    has_many   :shape_expressions, as: :paint
    belongs_to :non_poly, foreign_key: "non_poly_one_id", class_name: "NonPolyOne"
    include Remembered
  end
  class PaintTexture < ActiveRecord::Base
    has_many   :shape_expressions, as: :paint
    belongs_to :non_poly, foreign_key: "non_poly_two_id", class_name: "NonPolyTwo"
    include Remembered
  end
  class NonPolyOne < ActiveRecord::Base
    has_many :paint_colors
    include Remembered
  end
  class NonPolyTwo < ActiveRecord::Base
    has_many :paint_textures
    include Remembered
  end

  class EagerLoadPolyAssocsTest < ActiveRecord::TestCase
    NUM_SIMPLE_OBJS = 50
    NUM_SHAPE_EXPRESSIONS = 100

    def setup
      generate_test_object_graphs
    end

    teardown do
      [Circle, Square, Triangle, PaintColor, PaintTexture,
       ShapeExpression, NonPolyOne, NonPolyTwo].each(&:delete_all)
    end

    def generate_test_object_graphs
      1.upto(NUM_SIMPLE_OBJS) do
        [Circle, Square, Triangle, NonPolyOne, NonPolyTwo].map(&:create!)
      end
      1.upto(NUM_SIMPLE_OBJS) do
        PaintColor.create!(non_poly_one_id: NonPolyOne.sample.id)
        PaintTexture.create!(non_poly_two_id: NonPolyTwo.sample.id)
      end
      1.upto(NUM_SHAPE_EXPRESSIONS) do
        shape_type = [Circle, Square, Triangle].sample
        paint_type = [PaintColor, PaintTexture].sample
        ShapeExpression.create!(shape_type: shape_type.to_s, shape_id: shape_type.sample.id,
                                paint_type: paint_type.to_s, paint_id: paint_type.sample.id)
      end
    end

    def test_include_query
      res = ShapeExpression.all.merge!(includes: [ :shape, { paint: :non_poly } ]).to_a
      assert_equal NUM_SHAPE_EXPRESSIONS, res.size
      assert_queries(0) do
        res.each do |se|
          assert_not_nil se.paint.non_poly, "this is the association that was loading incorrectly before the change"
          assert_not_nil se.shape, "just making sure other associations still work"
        end
      end
    end
  end
end
