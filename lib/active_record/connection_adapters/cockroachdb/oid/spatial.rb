# frozen_string_literal: true

# Copyright 2024 The Cockroach Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module ActiveRecord
  module ConnectionAdapters
    module CockroachDB
      module OID
        class Spatial < Type::Value
          # sql_type is a string that comes from the database definition
          # examples:
          #   "geometry(Point,4326)"
          #   "geography(Point,4326)"
          #   "geometry(Polygon,4326) NOT NULL"
          #   "geometry(Geography,4326)"
          def initialize(oid, sql_type)
            @sql_type = sql_type
            @geo_type, @srid, @has_z, @has_m = self.class.parse_sql_type(sql_type)
            @spatial_factory =
              RGeo::ActiveRecord::SpatialFactoryStore.instance.factory(
                factory_attrs
              )
          end

          # sql_type: geometry, geometry(Point), geometry(Point,4326), ...
          #
          # returns [geo_type, srid, has_z, has_m]
          #   geo_type: geography, geometry, point, line_string, polygon, ...
          #   srid:     1234
          #   has_z:    false
          #   has_m:    false
          def self.parse_sql_type(sql_type)
            geo_type = nil
            srid = 0
            has_z = false
            has_m = false

            if sql_type =~ /(geography|geometry)\((.*)\)$/i
              # geometry(Point)
              # geometry(Point,4326)
              params = Regexp.last_match(2).split(',')
              if params.first =~ /([a-z]+[^zm])(z?)(m?)/i
                has_z = Regexp.last_match(2).length > 0
                has_m = Regexp.last_match(3).length > 0
                geo_type = Regexp.last_match(1)
              end
              srid = Regexp.last_match(1).to_i if params.last =~ /(\d+)/
            else
              geo_type = sql_type
            end
            [geo_type, srid, has_z, has_m]
          end

          def geographic?
            @sql_type =~ /geography/
          end

          def spatial?
            true
          end

          def type
            geographic? ? :geography : :geometry
          end

          # support setting an RGeo object or a WKT string
          def serialize(value)
            return if value.nil?

            geo_value = cast_value(value)

            # TODO: - only valid types should be allowed
            # e.g. linestring is not valid for point column
            # raise "maybe should raise" unless RGeo::Feature::Geometry.check_type(geo_value)

            RGeo::WKRep::WKBGenerator.new(hex_format: true, type_format: :ewkb, emit_ewkb_srid: true)
                                     .generate(geo_value)
          end

          private

          def cast_value(value)
            return if value.nil?

            value.is_a?(String) ? parse_wkt(value) : value
          end

          # convert WKT string into RGeo object
          def parse_wkt(string)
            wkt_parser(string).parse(string)
          rescue RGeo::Error::ParseError
            nil
          end

          def binary_string?(string)
            string[0] == "\x00" || string[0] == "\x01" || string[0, 4].match?(/[0-9a-fA-F]{4}/)
          end

          def wkt_parser(string)
            if binary_string?(string)
              RGeo::WKRep::WKBParser.new(@spatial_factory, support_ewkb: true, default_srid: @srid)
            else
              RGeo::WKRep::WKTParser.new(@spatial_factory, support_ewkt: true, default_srid: @srid)
            end
          end

          def factory_attrs
            {
              geo_type: @geo_type.underscore,
              has_m: @has_m,
              has_z: @has_z,
              srid: @srid,
              sql_type: type.to_s
            }
          end
        end
      end
    end
  end
end
