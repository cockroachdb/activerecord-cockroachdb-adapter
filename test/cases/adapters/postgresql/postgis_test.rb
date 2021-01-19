# frozen_string_literal: true

require "cases/helper_cockroachdb"
require "models/building"

class PostGISTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.connection
    spatial_factory_store.default = nil
    spatial_factory_store.clear
  end

  def test_postgis_available
    assert_equal postgis_version, @connection.postgis_lib_version
    valid_version = ["2.", "3."].any? { |major_ver| @connection.postgis_lib_version.start_with? major_ver }
    assert valid_version
  end

  def test_arel_visitor
    visitor = Arel::Visitors::CockroachDB.new(@connection)
    node = RGeo::ActiveRecord::SpatialConstantNode.new("POINT (1.0 2.0)")
    collector = Arel::Collectors::PlainString.new
    visitor.accept(node, collector)
    assert_equal "ST_GeomFromText('POINT (1.0 2.0)')", collector.value
  end

  def test_arel_visitor_will_not_visit_string
    visitor = Arel::Visitors::CockroachDB.new(@connection)
    node = "POINT (1 2)"
    collector = Arel::Collectors::PlainString.new

    assert_raises(Arel::Visitors::UnsupportedVisitError) do
      visitor.accept(node, collector)
    end
  end

  def test_set_and_get_point
    obj = klass.new
    assert_nil obj.coordinates
    obj.coordinates = factory.point(1.0, 2.0)
    assert_equal factory.point(1.0, 2.0), obj.coordinates
    assert_equal 3857, obj.coordinates.srid
  end

  def test_set_and_get_point_from_wkt
    obj = klass.new
    assert_nil obj.coordinates
    obj.coordinates = "POINT(1 2)"
    assert_equal factory.point(1.0, 2.0), obj.coordinates
    assert_equal 3857, obj.coordinates.srid
  end

  def test_save_and_load_point
    obj = klass.new
    obj.coordinates = factory.point(1.0, 2.0)
    obj.save!
    id = obj.id
    obj2 = klass.find(id)
    assert_equal factory.point(1.0, 2.0), obj2.coordinates
    assert_equal 3857, obj2.coordinates.srid
  end

  def test_save_and_load_geographic_point
    obj = klass.new
    obj.latlon = geographic_factory.point(1.0, 2.0)
    obj.save!
    id = obj.id
    obj2 = klass.find(id)
    assert_equal geographic_factory.point(1.0, 2.0), obj2.latlon
    assert_equal 4326, obj2.latlon.srid
  end

  def test_save_and_load_point_from_wkt
    obj = klass.new
    obj.coordinates = "POINT(1 2)"
    obj.save!
    id = obj.id
    obj2 = klass.find(id)
    assert_equal factory.point(1.0, 2.0), obj2.coordinates
    assert_equal 3857, obj2.coordinates.srid
  end

  def test_set_point_bad_wkt
    obj = klass.create(coordinates: "POINT (x)")
    assert_nil obj.coordinates
  end

  def test_set_point_wkt_wrong_type
    assert_raises(ActiveRecord::StatementInvalid) do
      klass.create(coordinates: "LINESTRING(1 2, 3 4, 5 6)")
    end
  end

  def test_custom_factory
    custom_factory = RGeo::Cartesian.preferred_factory(buffer_resolution: 8, srid: 3857)
    spatial_factory_store.register(custom_factory, geo_type: "polygon", srid: 3857)
    object = klass.new
    boundary = custom_factory.point(1, 2).buffer(3)
    object.boundary = boundary
    object.save!
    object.reload
    assert_equal boundary.to_s, object.boundary.to_s
    spatial_factory_store.clear
  end

  def test_spatial_factory_attrs_parsing
    klass.reset_column_information
    reset_memoized_spatial_factories

    factory = RGeo::Cartesian.preferred_factory(srid: 3857)
    spatial_factory_store.register(factory, { srid: 3857,
                                              sql_type: "geometry",
                                              geo_type: "polygon",
                                              has_z: false, has_m: false })

    # wrong factory for default
    spatial_factory_store.default = RGeo::Geographic.spherical_factory(srid: 4326)

    object = klass.new
    object.boundary = "POLYGON ((0 0, 0 1, 1 1, 1 0, 0 0))"
    object.save!
    object.reload
    assert_equal(factory, object.boundary.factory)

    spatial_factory_store.clear
  end

  def test_spatial_factory_retrieval
    reset_memoized_spatial_factories

    geo_factory = RGeo::Geographic.spherical_factory(srid: 4326)
    spatial_factory_store.register(geo_factory, geo_type: "point", sql_type: "geography")

    object = klass.new
    object.latlon = "POINT(-122 47)"
    point = object.latlon
    assert_equal 47, point.latitude
    object.shape = point

    # test that shape column will not use geographic factory
    object.save!
    object.reload
    refute_equal geo_factory, object.shape.factory

    spatial_factory_store.clear
  end

  def test_point_to_json
    obj = klass.new
    assert_match(/"latlon":null/, obj.to_json)
    obj.latlon = factory.point(1.0, 2.0)
    assert_match(/"latlon":"POINT\s\(1\.0\s2\.0\)"/, obj.to_json)
  end

  def test_custom_column
    rec = klass.new
    rec.latlon = "POINT(0 0)"
    rec.save
    refute_nil klass.select("CURRENT_TIMESTAMP as ts").first.ts
  end

  def test_multi_polygon_column
    rec = klass.new
    wkt = "MULTIPOLYGON (((-73.97210545302842 40.782991711401195, " \
          "-73.97228912063449 40.78274091498208, " \
          "-73.97235226842568 40.78276752827304, " \
          "-73.97216860098405 40.783018324791776, " \
          "-73.97210545302842 40.782991711401195)))"
    rec.m_poly = wkt
    assert rec.save
    rec = klass.find(rec.id) # force reload
    assert RGeo::Feature::MultiPolygon.check_type(rec.m_poly)
    assert_equal wkt, rec.m_poly.to_s
  end

  private

  def klass
    Building
  end

  def reset_memoized_spatial_factories
    # necessary to reset the @spatial_factory variable on spatial
    # OIDs, otherwise the results of early tests will be memoized
    # since the table is not dropped and recreated between test cases.
    ObjectSpace.each_object(spatial_oid) do |oid|
      oid.instance_variable_set(:@spatial_factory, nil)
    end
  end

  def spatial_oid
    ActiveRecord::ConnectionAdapters::CockroachDB::OID::Spatial
  end
end
