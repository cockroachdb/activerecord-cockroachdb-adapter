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
      module Quoting
        # CockroachDB does not allow inserting integer values into string
        # columns, but ActiveRecord expects this to work. CockroachDB will
        # however allow inserting string values into integer columns. It will
        # try to parse string values and convert them to integers so they can be
        # inserted in integer columns.
        #
        # We take advantage of this behavior here by forcing numeric values to
        # always be strings. Then, we won't have to make any additional changes
        # to ActiveRecord to support inserting integer values into string
        # columns.
        #
        # For spatial types, data is stored as Well-known Binary (WKB) strings
        # (https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry#Well-known_binary)
        # but when creating objects, using RGeo features is more convenient than
        # converting to WKB, so this does it automatically.
        def quote(value)
          if value.is_a?(Numeric)
            # NOTE: The fact that integers are quoted is important and helps
            # mitigate a potential vulnerability.
            #
            # See
            # - https://nvd.nist.gov/vuln/detail/CVE-2022-44566
            # - https://github.com/cockroachdb/activerecord-cockroachdb-adapter/pull/280#discussion_r1288692977
            "'#{quote_string(value.to_s)}'"
          elsif RGeo::Feature::Geometry.check_type(value)
            "'#{RGeo::WKRep::WKBGenerator.new(hex_format: true, type_format: :ewkb, emit_ewkb_srid: true).generate(value)}'"
          elsif value.is_a?(RGeo::Cartesian::BoundingBox)
            "'#{value.min_x},#{value.min_y},#{value.max_x},#{value.max_y}'::box"
          else
            super
          end
        end
      end
    end
  end
end
