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

module RGeo
  module ActiveRecord
    ##
    # Extend rgeo-activerecord visitors to use PostGIS specific functionality
    module SpatialToPostGISSql
      def visit_in_spatial_context(node, collector)
        # Use ST_GeomFromEWKT for EWKT geometries
        if node.is_a?(String) && node =~ /SRID=[\d+]{0,};/
          collector << "#{st_func('ST_GeomFromEWKT')}(#{quote(node)})"
        else
          super(node, collector)
        end
      end
    end
  end
end
RGeo::ActiveRecord::SpatialToSql.prepend RGeo::ActiveRecord::SpatialToPostGISSql

module Arel # :nodoc:
  module Visitors # :nodoc:
    class CockroachDB < PostgreSQL  # :nodoc:
      include RGeo::ActiveRecord::SpatialToSql

      def visit_Arel_Nodes_JoinSource(o, collector)
        super
        if o.aost
          collector << " AS OF SYSTEM TIME '#{o.aost.iso8601}'"
        end
        collector
      end
    end
  end
end
