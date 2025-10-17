# frozen_string_literal: true

require 'cases/helper_cockroachdb'
require 'models/building'

class SpatialQueriesTest < ActiveSupport::TestCase
  def setup
    Building.delete_all
  end

  def test_query_point
    obj = Building.create!(coordinates: factory.point(1, 2))
    id = obj.id
    assert_empty Building.where(coordinates: factory.point(2, 2))
    obj1 = Building.find_by(coordinates: factory.point(1, 2))
    refute_nil(obj1)
    assert_equal id, obj1.id
  end

  def test_query_multi_point
    obj = Building.create!(points: factory.multi_point([factory.point(1, 2)]))
    id = obj.id
    obj2 = Building.find_by(points: factory.multi_point([factory.point(1, 2)]))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
  end

  def test_query_point_wkt
    obj = Building.create!(coordinates: factory.point(1, 2))
    id = obj.id
    obj2 = Building.find_by(coordinates: 'SRID=3857;POINT(1 2)')
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = Building.find_by(coordinates: 'SRID=3857;POINT(2 2)')
    assert_nil(obj3)
  end

  def test_query_st_distance
    obj = Building.create!(coordinates: factory.point(1, 2))
    id = obj.id
    obj2 = Building.find_by(Building.arel_table[:coordinates].st_distance('SRID=3857;POINT(2 3)').lt(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = Building.find_by(Building.arel_table[:coordinates].st_distance('SRID=3857;POINT(2 3)').gt(2))
    assert_nil(obj3)
  end

  def test_query_st_distance_from_constant
    obj = Building.create!(coordinates: factory.point(1, 2))
    id = obj.id

    query_point = parser.parse('SRID=3857;POINT(2 3)')
    obj2 = Building.find_by(Arel.spatial(query_point).st_distance(Building.arel_table[:coordinates]).lt(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = Building.find_by(Arel.spatial(query_point).st_distance(Building.arel_table[:coordinates]).gt(2))
    assert_nil(obj3)
  end

  def test_query_st_length
    obj = Building.new
    obj.path = factory.line(factory.point(1.0, 2.0), factory.point(3.0, 2.0))
    obj.save!
    id = obj.id
    obj2 = Building.find_by(Building.arel_table[:path].st_length.eq(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = Building.find_by(Building.arel_table[:path].st_length.gt(3))
    assert_nil(obj3)
  end

  def test_query_rgeo_feature_node
    obj = Building.new
    obj.path = factory.line_string([factory.point(1.0, 2.0),
                                    factory.point(2.0, 2.0), factory.point(3.0, 2.0)])
    obj.save!
    id = obj.id

    query_point = factory.point(2.0, 2.0)
    obj2 = Building.find_by(Building.arel_table[:path].st_contains(query_point))
    assert_equal(id, obj2.id)

    query_point = factory.point(0.0, 2.0)
    obj3 = Building.find_by(Building.arel_table[:path].st_contains(query_point))
    assert_nil(obj3)
  end

  def test_query_rgeo_bbox_node
    obj = Building.new
    obj.coordinates = factory.point(1, 2)
    obj.save!
    id = obj.id

    pt1 = factory.point(-1, -1)
    pt2 = factory.point(4, 4)
    bbox = RGeo::Cartesian::BoundingBox.create_from_points(pt1, pt2)
    obj2 = Building.find_by(Building.arel_table[:coordinates].st_within(bbox))
    assert_equal(id, obj2.id)
  end

  def test_ewkt_parser_query
    obj = Building.create!(coordinates: factory.point(1, 2))
    id = obj.id

    query_point = parser.parse('SRID=3857;POINT(2 3)')
    obj2 = Building.find_by(Arel.spatial(query_point).st_distance(Building.arel_table[:coordinates]).lt(2))
    refute_nil(obj2)
    assert_equal(id, obj2.id)
    obj3 = Building.find_by(Arel.spatial(query_point).st_distance(Building.arel_table[:coordinates]).gt(2))
    assert_nil(obj3)
  end

  private

  def parser
    RGeo::WKRep::WKTParser.new(nil, support_ewkt: true)
  end
end
